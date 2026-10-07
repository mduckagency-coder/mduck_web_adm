-- ============================================================================
-- Periodo do ranking: enquanto o ranking do mes atual esta rodando (fim no
-- futuro), o "total ate agora" vem dos numeros atuais (streamer_stats, os
-- mesmos da Home) em vez de depender de um retrato salvo na importacao.
-- O desconto continua sendo o retrato do dia anterior ao inicio.
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

create or replace function ranking_window_values(p_agency uuid, p_period text, p_start date, p_end date)
returns table (streamer_id uuid, diamonds bigint, hours_live numeric, battles int, days_live int)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_running boolean := p_period = to_char(v_today, 'YYYY-MM') and p_end >= v_today - 1;
  v_end_snap date;
  v_base date;
begin
  if p_start is null then return; end if;
  if p_start > to_date(p_period || '-01', 'YYYY-MM-DD') then
    v_base := p_start - 1;
    if not exists (select 1 from metric_snapshots s where s.agency_id = p_agency and s.period_key = p_period and s.data_until = v_base) then
      v_base := null;
    end if;
  end if;

  if v_running then
    return query
      select e.streamer_id,
             greatest(coalesce(e.diamonds, 0) - coalesce(b.diamonds, 0), 0)::bigint,
             greatest(coalesce(e.hours_live, 0) - coalesce(b.hours_live, 0), 0)::numeric,
             greatest(coalesce(e.battles, 0) - coalesce(b.battles, 0), 0)::int,
             greatest(coalesce(e.days_live, 0) - coalesce(b.days_live, 0), 0)::int
      from streamer_stats e
      join profiles p on p.id = e.streamer_id and p.agency_id = p_agency
      left join metric_snapshots b on b.streamer_id = e.streamer_id and b.period_key = p_period and b.data_until = v_base;
    return;
  end if;

  select max(s.data_until) into v_end_snap from metric_snapshots s
  where s.agency_id = p_agency and s.period_key = p_period and s.data_until <= p_end;
  if v_end_snap is null then return; end if;
  return query
    select e.streamer_id,
           greatest(e.diamonds - coalesce(b.diamonds, 0), 0)::bigint,
           greatest(e.hours_live - coalesce(b.hours_live, 0), 0)::numeric,
           greatest(e.battles - coalesce(b.battles, 0), 0)::int,
           greatest(e.days_live - coalesce(b.days_live, 0), 0)::int
    from metric_snapshots e
    left join metric_snapshots b on b.streamer_id = e.streamer_id and b.period_key = p_period and b.data_until = v_base
    where e.agency_id = p_agency and e.period_key = p_period and e.data_until = v_end_snap;
end;
$$;

create or replace function ranking_window_warning(p_agency uuid, p_period text, p_start date, p_end date)
returns text
language sql stable security definer
set search_path = public
as $$
  select case
    when p_start is null then null
    when p_start > to_date(p_period || '-01', 'YYYY-MM-DD')
         and not exists (select 1 from metric_snapshots s where s.agency_id = p_agency and s.period_key = p_period and s.data_until = p_start - 1) then 'sem_base'
    when not (p_period = to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM') and p_end >= (now() at time zone 'America/Sao_Paulo')::date - 1)
         and not exists (select 1 from metric_snapshots s where s.agency_id = p_agency and s.period_key = p_period and s.data_until <= p_end) then 'sem_dados'
    else null end;
$$;

notify pgrst, 'reload schema';

-- Icone da categoria "Recursos do LIVE" (antes 🧰)
update academy_categories set emoji = '📱' where slug = 'recursos';

-- Conferencia: periodo salvo e base do dia 01
select w.period_key, w.metric, w.start_date, w.end_date,
       (select count(*) from metric_snapshots s where s.agency_id = w.agency_id and s.period_key = w.period_key and s.data_until = w.start_date - 1) as streamers_com_base
from ranking_windows w order by w.period_key desc, w.metric;

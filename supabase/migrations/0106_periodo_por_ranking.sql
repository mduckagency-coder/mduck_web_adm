-- ============================================================================
-- Periodo do ranking POR RANKING (rode depois da 0105)
--   metric = 'todos'    vale para todos os rankings do mes
--            'diamonds' Diamantes (e Top Games / Top Musicos, que usam diamantes)
--            'hours'    Horas
--            'battles'  Batalhas
-- O periodo especifico de um ranking tem prioridade sobre o de 'todos'.
-- Sem nenhum registro: mes inteiro (padrao).
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

alter table ranking_windows add column if not exists metric text not null default 'todos';
alter table ranking_windows drop constraint if exists ranking_windows_metric_check;
alter table ranking_windows add constraint ranking_windows_metric_check check (metric in ('todos', 'diamonds', 'hours', 'battles'));
alter table ranking_windows drop constraint if exists ranking_windows_agency_id_period_key_key;
drop index if exists ranking_windows_agency_period_metric;
create unique index ranking_windows_agency_period_metric on ranking_windows(agency_id, period_key, metric);

-- totais de cada streamer num periodo (total ate o fim - total ate o dia
-- anterior ao inicio). warning: 'sem_base' (falta a importacao do dia
-- anterior ao inicio; conta desde o dia 1) | 'sem_dados'.
create or replace function ranking_window_values(p_agency uuid, p_period text, p_start date, p_end date)
returns table (streamer_id uuid, diamonds bigint, hours_live numeric, battles int, days_live int)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_end_snap date;
  v_base date;
begin
  if p_start is null then return; end if;
  select max(s.data_until) into v_end_snap from metric_snapshots s
  where s.agency_id = p_agency and s.period_key = p_period and s.data_until <= p_end;
  if v_end_snap is null then return; end if;
  if p_start > to_date(p_period || '-01', 'YYYY-MM-DD') then
    v_base := p_start - 1;
    if not exists (select 1 from metric_snapshots s where s.agency_id = p_agency and s.period_key = p_period and s.data_until = v_base) then
      v_base := null;
    end if;
  end if;
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
    when not exists (select 1 from metric_snapshots s where s.agency_id = p_agency and s.period_key = p_period and s.data_until <= p_end) then 'sem_dados'
    when p_start > to_date(p_period || '-01', 'YYYY-MM-DD')
         and not exists (select 1 from metric_snapshots s where s.agency_id = p_agency and s.period_key = p_period and s.data_until = p_start - 1) then 'sem_base'
    else null end;
$$;

create or replace function app_ranking_rows(p_period text default null)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_agency uuid := coalesce(
    (select agency_id from profiles where auth_user_id = auth.uid() limit 1),
    (select agency_id from managers where id = auth.uid() limit 1));
  v_cur text := to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM');
  v_period text := coalesce(nullif(p_period, ''), v_cur);
  w_all ranking_windows;
  w_d ranking_windows;
  w_h ranking_windows;
  w_b ranking_windows;
  v_windows jsonb := '{}'::jsonb;
  v_rows jsonb;
begin
  if v_agency is null then raise exception 'sem agencia'; end if;
  select * into w_all from ranking_windows r where r.agency_id = v_agency and r.period_key = v_period and r.metric = 'todos';
  select * into w_d from ranking_windows r where r.agency_id = v_agency and r.period_key = v_period and r.metric = 'diamonds';
  select * into w_h from ranking_windows r where r.agency_id = v_agency and r.period_key = v_period and r.metric = 'hours';
  select * into w_b from ranking_windows r where r.agency_id = v_agency and r.period_key = v_period and r.metric = 'battles';
  -- o especifico vale mais que o de todos
  if w_d.id is null then w_d := w_all; end if;
  if w_h.id is null then w_h := w_all; end if;
  if w_b.id is null then w_b := w_all; end if;

  if w_d.id is not null then
    v_windows := v_windows || jsonb_build_object('diamonds', jsonb_build_object('start_date', w_d.start_date, 'end_date', w_d.end_date,
      'warning', ranking_window_warning(v_agency, v_period, w_d.start_date, w_d.end_date)));
  end if;
  if w_h.id is not null then
    v_windows := v_windows || jsonb_build_object('hours', jsonb_build_object('start_date', w_h.start_date, 'end_date', w_h.end_date,
      'warning', ranking_window_warning(v_agency, v_period, w_h.start_date, w_h.end_date)));
  end if;
  if w_b.id is not null then
    v_windows := v_windows || jsonb_build_object('battles', jsonb_build_object('start_date', w_b.start_date, 'end_date', w_b.end_date,
      'warning', ranking_window_warning(v_agency, v_period, w_b.start_date, w_b.end_date)));
  end if;

  with dflt as (
    -- mes inteiro (padrao)
    select s.streamer_id, coalesce(s.diamonds, 0)::bigint as diamonds, coalesce(s.hours_live, 0)::numeric as hours_live,
           coalesce(s.battles, 0)::int as battles, coalesce(s.days_live, 0)::int as days_live, null::text as avatar_url
    from streamer_stats s where v_period = v_cur
    union all
    select m.streamer_id, coalesce(m.diamonds, 0)::bigint, coalesce(m.hours_live, 0)::numeric,
           coalesce(m.battles, 0)::int, coalesce(m.days_live, 0)::int, m.avatar_url
    from monthly_stats m where v_period <> v_cur and m.period_key = v_period
  ),
  xd as (select * from ranking_window_values(v_agency, v_period, w_d.start_date, w_d.end_date)),
  xh as (select * from ranking_window_values(v_agency, v_period, w_h.start_date, w_h.end_date)),
  xb as (select * from ranking_window_values(v_agency, v_period, w_b.start_date, w_b.end_date)),
  quem as (
    select streamer_id from dflt
    union select streamer_id from xd union select streamer_id from xh union select streamer_id from xb
  )
  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
    select p.id, p.display_name, coalesce(d.avatar_url, p.avatar_url) as avatar_url, p.category_id, c.name as category_name,
           case when w_d.id is null then coalesce(d.diamonds, 0) else coalesce(xd.diamonds, 0) end as diamonds,
           case when w_h.id is null then coalesce(d.hours_live, 0) else coalesce(xh.hours_live, 0) end as hours_live,
           case when w_b.id is null then coalesce(d.battles, 0) else coalesce(xb.battles, 0) end as battles,
           coalesce(d.days_live, 0) as days_live
    from quem q
    join profiles p on p.id = q.streamer_id
    left join dflt d on d.streamer_id = p.id
    left join xd on xd.streamer_id = p.id
    left join xh on xh.streamer_id = p.id
    left join xb on xb.streamer_id = p.id
    left join streamer_categories c on c.id = p.category_id
    where p.agency_id = v_agency and (v_period <> v_cur or p.is_active)) x;

  return jsonb_build_object('period_key', v_period, 'custom', v_windows <> '{}'::jsonb, 'windows', v_windows, 'rows', v_rows);
end;
$$;
grant execute on function app_ranking_rows(text) to authenticated;

notify pgrst, 'reload schema';

-- ============================================================================
-- Periodo do ranking por mes (padrao: mes inteiro)
--
-- * metric_snapshots: a cada importacao, guarda os totais de cada streamer
--   "ate o dia X" (fim do periodo da planilha). E isso que permite contar o
--   ranking a partir de um dia: total ate o fim - total ate o dia anterior.
-- * ranking_windows: um registro por mes que tiver periodo diferente
--   (ex.: Outubro/2026 de 02/10 a 31/10). Sem registro = mes inteiro.
-- * app_ranking_rows(periodo): numeros do ranking ja no periodo certo; usado
--   pelo Ranking geral, "Meu ranking" e a posicao na Home.
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

create table if not exists metric_snapshots (
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id) on delete cascade,
  period_key text not null,
  data_until date not null,
  diamonds bigint not null default 0,
  hours_live numeric not null default 0,
  days_live int not null default 0,
  battles int not null default 0,
  created_at timestamptz not null default now(),
  primary key (streamer_id, period_key, data_until)
);
create index if not exists idx_metric_snapshots_agency on metric_snapshots(agency_id, period_key, data_until);
alter table metric_snapshots enable row level security;
drop policy if exists "metric_snapshots_managers" on metric_snapshots;
create policy "metric_snapshots_managers" on metric_snapshots for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

create table if not exists ranking_windows (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  period_key text not null,
  start_date date not null,
  end_date date not null,
  note text,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  unique (agency_id, period_key),
  check (end_date >= start_date)
);
alter table ranking_windows enable row level security;
drop policy if exists "ranking_windows_managers" on ranking_windows;
create policy "ranking_windows_managers" on ranking_windows for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- ----------------------------------------------------------------------------
-- Numeros do ranking de um mes, para a agencia de quem chama
-- ----------------------------------------------------------------------------
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
  v_month_start date := to_date(v_period || '-01', 'YYYY-MM-DD');
  w ranking_windows;
  v_end_snap date;
  v_base date;
  v_warning text;
  v_rows jsonb;
begin
  if v_agency is null then raise exception 'sem agencia'; end if;
  select * into w from ranking_windows r where r.agency_id = v_agency and r.period_key = v_period;

  if w.id is null then
    -- padrao: mes inteiro (como sempre foi)
    if v_period = v_cur then
      select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
        select p.id, p.display_name, p.avatar_url, p.category_id, c.name as category_name,
               coalesce(s.diamonds, 0) as diamonds, coalesce(s.hours_live, 0) as hours_live,
               coalesce(s.battles, 0) as battles, coalesce(s.days_live, 0) as days_live
        from profiles p
        left join streamer_stats s on s.streamer_id = p.id
        left join streamer_categories c on c.id = p.category_id
        where p.agency_id = v_agency and p.is_active) x;
    else
      select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
        select p.id, p.display_name, coalesce(m.avatar_url, p.avatar_url) as avatar_url, p.category_id, c.name as category_name,
               coalesce(m.diamonds, 0) as diamonds, coalesce(m.hours_live, 0) as hours_live,
               coalesce(m.battles, 0) as battles, coalesce(m.days_live, 0) as days_live
        from monthly_stats m
        join profiles p on p.id = m.streamer_id
        left join streamer_categories c on c.id = p.category_id
        where p.agency_id = v_agency and m.period_key = v_period) x;
    end if;
    return jsonb_build_object('period_key', v_period, 'custom', false, 'rows', v_rows);
  end if;

  -- periodo personalizado: total ate o fim - total ate o dia anterior ao inicio
  select max(data_until) into v_end_snap from metric_snapshots
  where agency_id = v_agency and period_key = v_period and data_until <= w.end_date;

  if w.start_date > v_month_start then
    v_base := w.start_date - 1;
    if not exists (select 1 from metric_snapshots where agency_id = v_agency and period_key = v_period and data_until = v_base) then
      v_warning := 'sem_base';
      v_base := null; -- sem os numeros do dia anterior, conta desde o dia 1
    end if;
  end if;
  if v_end_snap is null then v_warning := coalesce(v_warning, 'sem_dados'); end if;

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_rows from (
    select p.id, p.display_name, p.avatar_url, p.category_id, c.name as category_name,
           greatest(e.diamonds - coalesce(b.diamonds, 0), 0) as diamonds,
           greatest(e.hours_live - coalesce(b.hours_live, 0), 0) as hours_live,
           greatest(e.battles - coalesce(b.battles, 0), 0) as battles,
           greatest(e.days_live - coalesce(b.days_live, 0), 0) as days_live
    from metric_snapshots e
    join profiles p on p.id = e.streamer_id
    left join metric_snapshots b on b.streamer_id = e.streamer_id and b.period_key = v_period and b.data_until = v_base
    left join streamer_categories c on c.id = p.category_id
    where e.agency_id = v_agency and e.period_key = v_period and e.data_until = v_end_snap
      and (v_period <> v_cur or p.is_active)) x;

  return jsonb_build_object(
    'period_key', v_period, 'custom', true,
    'start_date', w.start_date, 'end_date', w.end_date,
    'data_until', v_end_snap, 'warning', v_warning,
    'rows', v_rows);
end;
$$;
grant execute on function app_ranking_rows(text) to authenticated;

notify pgrst, 'reload schema';

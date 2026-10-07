-- ============================================================================
-- Artes dos Marcos do Mes: CLASSICA (padrao do marco, vale todo mes) e
-- COMEMORATIVA (por mes: Natal, Halloween, aniversario da agencia...).
-- slots = areas detectadas automaticamente na arte (circulo da foto e placa do
-- @/mes), em coordenadas relativas -- o app monta a arte de cada streamer.
-- + textos editaveis da Jornada e historico de marcos pra linha do tempo.
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

alter table monthly_milestone_arts add column if not exists kind text not null default 'comemorativa';
alter table monthly_milestone_arts drop constraint if exists monthly_milestone_arts_kind_check;
alter table monthly_milestone_arts add constraint monthly_milestone_arts_kind_check check (kind in ('classica', 'comemorativa'));
alter table monthly_milestone_arts add column if not exists label text;
alter table monthly_milestone_arts add column if not exists slots jsonb;

-- artes ja enviadas (por mes) viram a CLASSICA do marco, se ainda nao houver uma
update monthly_milestone_arts a
set period_key = 'classica', kind = 'classica', updated_at = now()
where a.kind <> 'classica' and a.period_key <> 'classica'
  and not exists (
    select 1 from monthly_milestone_arts c
    where c.agency_id = a.agency_id and c.milestone_id = a.milestone_id and c.period_key = 'classica'
  )
  and a.id = (
    select x.id from monthly_milestone_arts x
    where x.agency_id = a.agency_id and x.milestone_id = a.milestone_id and x.period_key <> 'classica'
    order by x.updated_at desc limit 1
  );

-- marcos do mes pro app: arte classica + comemorativa do mes (se houver)
drop function if exists app_my_month_milestones(text);
create or replace function app_my_month_milestones(p_period text default null)
returns table (
  milestone_id uuid, value numeric, title text, importance int,
  reached boolean, unlocked_at timestamptz, seen boolean, is_highest boolean,
  period_key text, current_diamonds numeric,
  classic_url text, classic_slots jsonb,
  special_url text, special_slots jsonb, special_label text
)
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_agency uuid;
  v_period text := coalesce(p_period, to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM'));
  v_cur numeric;
  v_top numeric;
begin
  select p.id, p.agency_id into v_me, v_agency from profiles p where p.auth_user_id = auth.uid() limit 1;
  if v_me is null then return; end if;
  perform evaluate_streamer_month_milestones(v_me);

  select coalesce(max(s.diamonds), 0) into v_cur from streamer_month_series(v_me) s where s.period_key = v_period;
  select max(m.value) into v_top
  from streamer_monthly_milestones smm join monthly_milestones m on m.id = smm.milestone_id
  where smm.streamer_id = v_me and smm.period_key = v_period;

  return query
    select m.id, m.value, m.title, m.importance,
           smm.id is not null, smm.unlocked_at, (smm.id is null or smm.seen_at is not null),
           (smm.id is not null and m.value = v_top),
           v_period, v_cur,
           cl.image_url, cl.slots,
           sp.image_url, sp.slots, sp.label
    from monthly_milestones m
    left join streamer_monthly_milestones smm
      on smm.milestone_id = m.id and smm.streamer_id = v_me and smm.period_key = v_period
    left join monthly_milestone_arts cl
      on cl.milestone_id = m.id and cl.agency_id = v_agency and cl.period_key = 'classica'
    left join monthly_milestone_arts sp
      on sp.milestone_id = m.id and sp.agency_id = v_agency and sp.period_key = v_period and sp.kind = 'comemorativa'
    where m.agency_id = v_agency and m.is_active
    order by m.value;
end;
$$;
grant execute on function app_my_month_milestones(text) to authenticated;

-- historico: maior marco de cada mes (linha do tempo da Jornada)
create or replace function app_my_milestone_history()
returns table (period_key text, value numeric, title text, importance int, unlocked_at timestamptz)
language sql stable security definer
set search_path = public
as $$
  select distinct on (smm.period_key) smm.period_key, m.value, m.title, m.importance, smm.unlocked_at
  from streamer_monthly_milestones smm
  join monthly_milestones m on m.id = smm.milestone_id
  join profiles p on p.id = smm.streamer_id
  where p.auth_user_id = auth.uid()
  order by smm.period_key desc, m.value desc;
$$;
grant execute on function app_my_milestone_history() to authenticated;

-- textos editaveis da Jornada (painel > Inventario > Configuracoes)
create or replace function app_journey_texts()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select jsonb_build_object(
    'title', coalesce(c.value ->> 'journey_title', 'Sua jornada na MDuck'),
    'subtitle', coalesce(c.value ->> 'journey_subtitle', 'Um registro dos momentos que marcaram sua trajetória.')
  )
  from profiles p
  left join app_settings c on c.agency_id = p.agency_id and c.key = 'journey_config'
  where p.auth_user_id = auth.uid()
  limit 1;
$$;
grant execute on function app_journey_texts() to authenticated;

notify pgrst, 'reload schema';

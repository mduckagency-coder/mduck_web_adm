-- ============================================================================
-- JORNADA (app) / Inventario (painel): Trilha + Conquistas + Marcos do Mes +
-- Brasoes + correcao manual auditada.
--
-- Reaproveita (nao duplica):
--   achievements / streamer_achievements (0091)  -> conquistas e pontos da trilha
--   streamer_month_series (0091)                 -> historico real (monthly_stats
--                                                    + mes atual de streamer_stats)
--   streamer_inventory_entries (0059/0090)       -> Jornada MDUCK (sem mudanca)
--
-- Novo:
--   achievements.trail_stage/trail_order/icon_key  posicao na Trilha (editavel)
--   regra month_combo                              "80K + 22 dias + 100h" no mesmo mes
--   monthly_milestones                             escada dos Marcos do Mes (editavel)
--   monthly_milestone_arts                         arte por mes + marco (upload no painel)
--   streamer_monthly_milestones                    marcos que cada streamer bateu em cada mes
--   journey_stages                                 brasoes/estagios + criterios + textos
--   achievement_adjustments                        auditoria das correcoes manuais
--
-- Historico prevalece: tudo e calculado sobre todos os meses ja importados,
-- entao quem tem 2 anos de historico ja entra com o que conquistou.
--
-- Aditivo/idempotente. Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Conquistas: trilha, icone, novas familias/regras, correcao manual
-- ----------------------------------------------------------------------------
alter table achievements add column if not exists trail_stage text;
alter table achievements add column if not exists trail_order int;
alter table achievements add column if not exists icon_key text;

alter table achievements drop constraint if exists achievements_family_check;
alter table achievements add constraint achievements_family_check
  check (family in ('marco', 'mensal', 'consistencia', 'horas', 'dias', 'primeira', 'grande_marco', 'merito'));

alter table achievements drop constraint if exists achievements_rule_type_check;
alter table achievements add constraint achievements_rule_type_check
  check (rule_type in ('total_diamonds', 'month_diamonds', 'consecutive_months_diamonds',
                       'month_hours', 'total_hours', 'month_days', 'month_combo'));

alter table achievements drop constraint if exists achievements_trail_stage_check;
alter table achievements add constraint achievements_trail_stage_check
  check (trail_stage is null or trail_stage in ('primeiros_passos', 'dedicacao', 'resultados', 'grande_marco', 'merito'));

-- correcao manual: o calculo original fica guardado (value_at_unlock/source)
alter table streamer_achievements add column if not exists revoked_at timestamptz;
alter table streamer_achievements add column if not exists revoked_by uuid;
alter table streamer_achievements add column if not exists revoke_reason text;
alter table streamer_achievements add column if not exists manual_by uuid;
alter table streamer_achievements add column if not exists manual_reason text;

create table if not exists achievement_adjustments (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id) on delete cascade,
  achievement_id uuid not null references achievements(id) on delete cascade,
  action text not null check (action in ('unlock', 'revoke')),
  reason text not null,
  calculated_value numeric,
  calculated_unlocked boolean,
  manual_value numeric,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists idx_achievement_adjustments_streamer on achievement_adjustments(streamer_id, created_at desc);
alter table achievement_adjustments enable row level security;
drop policy if exists "achievement_adjustments_agency" on achievement_adjustments;
create policy "achievement_adjustments_agency" on achievement_adjustments
  for select using (agency_id = (select agency_id from managers where id = auth.uid()));

-- ----------------------------------------------------------------------------
-- 2) Marcos do Mes (escada configuravel) + artes por mes + registro
-- ----------------------------------------------------------------------------
create table if not exists monthly_milestones (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  value numeric not null check (value > 0),
  title text,
  -- importancia visual progressiva (1 = bonito ... 8 = extremamente especial)
  importance int not null default 1 check (importance between 1 and 8),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agency_id, value)
);

create table if not exists monthly_milestone_arts (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  period_key text not null,              -- 'AAAA-MM'
  milestone_id uuid not null references monthly_milestones(id) on delete cascade,
  image_url text not null,
  template jsonb,                        -- futuro: template com nome/diamantes/mes/marca
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agency_id, period_key, milestone_id)
);

create table if not exists streamer_monthly_milestones (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id) on delete cascade,
  period_key text not null,
  milestone_id uuid not null references monthly_milestones(id) on delete cascade,
  value_at_unlock numeric,
  unlocked_at timestamptz not null default now(),
  seen_at timestamptz,
  unique (streamer_id, period_key, milestone_id)
);
create index if not exists idx_streamer_monthly_milestones_period on streamer_monthly_milestones(agency_id, period_key);

alter table monthly_milestones enable row level security;
alter table monthly_milestone_arts enable row level security;
alter table streamer_monthly_milestones enable row level security;

drop policy if exists "monthly_milestones_agency" on monthly_milestones;
create policy "monthly_milestones_agency" on monthly_milestones
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "monthly_milestone_arts_agency" on monthly_milestone_arts;
create policy "monthly_milestone_arts_agency" on monthly_milestone_arts
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "streamer_monthly_milestones_agency" on streamer_monthly_milestones;
create policy "streamer_monthly_milestones_agency" on streamer_monthly_milestones
  for select using (agency_id = (select agency_id from managers where id = auth.uid()));

-- ----------------------------------------------------------------------------
-- 3) Brasoes / estagios da jornada (classificacao interna, nome configuravel)
-- ----------------------------------------------------------------------------
create table if not exists journey_stages (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  key text not null,                     -- interno, nunca mostrado ao streamer
  name text not null,                    -- nome do estagio exibido no app
  description text,
  crest_key text not null default 'prata' check (crest_key in ('prata', 'cristal', 'premium', 'merito')),
  crest_image_url text,                  -- opcional: arte propria substitui o desenho
  sort_order int not null default 0,
  -- criterio: pelo menos min_months meses (na janela) com diamantes >= min_value
  min_value numeric not null default 0,
  min_months int not null default 0,
  -- meta adaptativa
  goal_mode text not null default 'next_step' check (goal_mode in ('next_step', 'horizon')),
  goal_label text not null default 'Seu próximo marco',
  secondary_mode text not null default 'horizon' check (secondary_mode in ('none', 'horizon', 'next_after_goal')),
  secondary_label text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agency_id, key)
);
alter table journey_stages enable row level security;
drop policy if exists "journey_stages_agency" on journey_stages;
create policy "journey_stages_agency" on journey_stages
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- ----------------------------------------------------------------------------
-- 4) Regras: valor de progresso (com month_combo)
-- ----------------------------------------------------------------------------
create or replace function achievement_rule_value(p_streamer_id uuid, p_rule_type text, p_threshold numeric, p_config jsonb)
returns numeric
language plpgsql stable security definer
set search_path = public
as $$
declare
  r record;
  v_best numeric := 0;
  v_streak int := 0;
  v_prev_key text;
  v_days numeric := greatest(coalesce((p_config ->> 'days')::numeric, 0), 0);
  v_hours numeric := greatest(coalesce((p_config ->> 'hours')::numeric, 0), 0);
  v_ratio numeric;
begin
  if p_rule_type = 'total_diamonds' then
    select coalesce(sum(diamonds), 0) into v_best from streamer_month_series(p_streamer_id);
  elsif p_rule_type = 'total_hours' then
    select coalesce(sum(hours), 0) into v_best from streamer_month_series(p_streamer_id);
  elsif p_rule_type = 'month_diamonds' then
    select coalesce(max(diamonds), 0) into v_best from streamer_month_series(p_streamer_id);
  elsif p_rule_type = 'month_hours' then
    select coalesce(max(hours), 0) into v_best from streamer_month_series(p_streamer_id);
  elsif p_rule_type = 'month_days' then
    select coalesce(max(days), 0) into v_best from streamer_month_series(p_streamer_id);
  elsif p_rule_type = 'month_combo' then
    -- melhor mes pelo requisito mais distante (0..1) * threshold, pra barra
    for r in select * from streamer_month_series(p_streamer_id) loop
      v_ratio := least(
        case when p_threshold > 0 then r.diamonds / p_threshold else 1 end,
        case when v_days > 0 then r.days / v_days else 1 end,
        case when v_hours > 0 then r.hours / v_hours else 1 end,
        1);
      v_best := greatest(v_best, v_ratio * p_threshold);
    end loop;
  elsif p_rule_type = 'consecutive_months_diamonds' then
    for r in select * from streamer_month_series(p_streamer_id) loop
      if r.diamonds >= p_threshold
         and v_prev_key is not null
         and to_char(to_date(v_prev_key || '-01', 'YYYY-MM-DD') + interval '1 month', 'YYYY-MM') = r.period_key
         and v_streak > 0 then
        v_streak := v_streak + 1;
      elsif r.diamonds >= p_threshold then
        v_streak := 1;
      else
        v_streak := 0;
      end if;
      v_best := greatest(v_best, v_streak);
      v_prev_key := r.period_key;
    end loop;
  end if;
  return v_best;
end;
$$;

-- ----------------------------------------------------------------------------
-- 5) Avaliacao automatica das conquistas (agora com month_combo).
--    Ja existe linha (desbloqueada OU revogada manualmente) -> nao mexe:
--    a primeira data nunca muda e a decisao manual prevalece.
-- ----------------------------------------------------------------------------
create or replace function evaluate_streamer_achievements(p_streamer_id uuid)
returns int
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_agency uuid;
  a record;
  r record;
  v_acc numeric;
  v_streak int;
  v_prev_key text;
  v_needed int;
  v_days numeric;
  v_hours numeric;
  v_found boolean;
  v_key text;
  v_end timestamptz;
  v_is_current boolean;
  v_count int := 0;
begin
  select agency_id into v_agency from profiles where id = p_streamer_id;
  if v_agency is null then return 0; end if;

  for a in
    select * from achievements x
    where x.agency_id = v_agency and x.is_active
      and not exists (select 1 from streamer_achievements sa where sa.streamer_id = p_streamer_id and sa.achievement_id = x.id)
  loop
    v_found := false;
    v_acc := 0;
    v_streak := 0;
    v_prev_key := null;
    v_needed := greatest(coalesce((a.config ->> 'months')::int, 3), 1);
    v_days := greatest(coalesce((a.config ->> 'days')::numeric, 0), 0);
    v_hours := greatest(coalesce((a.config ->> 'hours')::numeric, 0), 0);

    for r in select * from streamer_month_series(p_streamer_id) loop
      if a.rule_type = 'total_diamonds' then
        v_acc := v_acc + r.diamonds;
        if v_acc >= a.threshold then v_found := true; end if;
      elsif a.rule_type = 'total_hours' then
        v_acc := v_acc + r.hours;
        if v_acc >= a.threshold then v_found := true; end if;
      elsif a.rule_type = 'month_diamonds' then
        v_acc := r.diamonds;
        if r.diamonds >= a.threshold then v_found := true; end if;
      elsif a.rule_type = 'month_hours' then
        v_acc := r.hours;
        if r.hours >= a.threshold then v_found := true; end if;
      elsif a.rule_type = 'month_days' then
        v_acc := r.days;
        if r.days >= a.threshold then v_found := true; end if;
      elsif a.rule_type = 'month_combo' then
        v_acc := r.diamonds;
        if r.diamonds >= a.threshold and r.days >= v_days and r.hours >= v_hours then v_found := true; end if;
      elsif a.rule_type = 'consecutive_months_diamonds' then
        if r.diamonds >= a.threshold
           and v_streak > 0
           and to_char(to_date(v_prev_key || '-01', 'YYYY-MM-DD') + interval '1 month', 'YYYY-MM') = r.period_key then
          v_streak := v_streak + 1;
        elsif r.diamonds >= a.threshold then
          v_streak := 1;
        else
          v_streak := 0;
        end if;
        v_prev_key := r.period_key;
        v_acc := v_streak;
        if v_streak >= v_needed then v_found := true; end if;
      end if;
      if v_found then
        v_key := r.period_key; v_end := r.period_end; v_is_current := r.is_current;
        exit;
      end if;
    end loop;

    if v_found then
      insert into streamer_achievements (agency_id, streamer_id, achievement_id, unlocked_at, value_at_unlock, period_key, seen_at)
      values (v_agency, p_streamer_id, a.id, v_end, v_acc, v_key,
              case when v_is_current then null else now() end)
      on conflict (streamer_id, achievement_id) do nothing;
      if found then v_count := v_count + 1; end if;
    end if;
  end loop;
  return v_count;
end;
$$;

-- ----------------------------------------------------------------------------
-- 6) Marcos do Mes: registra todos os marcos batidos em cada mes (historico
--    inclusive). Mes fechado entra como visto; mes atual dispara celebracao.
-- ----------------------------------------------------------------------------
create or replace function evaluate_streamer_month_milestones(p_streamer_id uuid)
returns int
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_agency uuid;
  v_count int := 0;
  v_n int;
begin
  select agency_id into v_agency from profiles where id = p_streamer_id;
  if v_agency is null then return 0; end if;

  insert into streamer_monthly_milestones (agency_id, streamer_id, period_key, milestone_id, value_at_unlock, unlocked_at, seen_at)
  select v_agency, p_streamer_id, s.period_key, m.id, s.diamonds,
         case when s.is_current then now() else s.period_end end,
         case when s.is_current then null else now() end
  from streamer_month_series(p_streamer_id) s
  join monthly_milestones m on m.agency_id = v_agency and m.is_active and s.diamonds >= m.value
  on conflict (streamer_id, period_key, milestone_id) do nothing;
  get diagnostics v_n = row_count;
  v_count := v_count + v_n;

  -- mantem o valor do mes atual atualizado (o maior marco depende dele)
  update streamer_monthly_milestones smm
  set value_at_unlock = s.diamonds
  from streamer_month_series(p_streamer_id) s
  where smm.streamer_id = p_streamer_id and smm.period_key = s.period_key and s.is_current
    and smm.value_at_unlock is distinct from s.diamonds;

  return v_count;
end;
$$;

-- trigger da importacao: conquistas + marcos do mes
create or replace function trg_evaluate_achievements()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  begin
    perform evaluate_streamer_achievements(new.streamer_id);
  exception when others then
    null;
  end;
  begin
    perform evaluate_streamer_month_milestones(new.streamer_id);
  exception when others then
    null;
  end;
  return new;
end;
$$;

create or replace function evaluate_agency_achievements()
returns int
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_agency uuid;
  p record;
  v_total int := 0;
begin
  select agency_id into v_agency from managers where id = auth.uid();
  if v_agency is null then raise exception 'apenas gestores'; end if;
  for p in select id from profiles where agency_id = v_agency loop
    v_total := v_total + evaluate_streamer_achievements(p.id);
    perform evaluate_streamer_month_milestones(p.id);
  end loop;
  return v_total;
end;
$$;

-- ----------------------------------------------------------------------------
-- 7) Correcao manual (painel). Guarda calculado x manual, quem, quando, motivo.
-- ----------------------------------------------------------------------------
create or replace function admin_adjust_achievement(
  p_streamer_id uuid, p_achievement_id uuid, p_action text, p_reason text, p_manual_value numeric default null)
returns void
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_agency uuid;
  a record;
  v_calc numeric;
  v_calc_unlocked boolean;
begin
  select agency_id into v_agency from managers where id = auth.uid();
  if v_agency is null then raise exception 'apenas gestores'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'informe o motivo'; end if;
  select * into a from achievements where id = p_achievement_id and agency_id = v_agency;
  if not found then raise exception 'conquista nao encontrada'; end if;
  if not exists (select 1 from profiles where id = p_streamer_id and agency_id = v_agency) then
    raise exception 'streamer nao encontrado';
  end if;

  v_calc := achievement_rule_value(p_streamer_id, a.rule_type, a.threshold, a.config);
  v_calc_unlocked := case
    when a.rule_type = 'consecutive_months_diamonds' then v_calc >= greatest(coalesce((a.config ->> 'months')::int, 3), 1)
    else v_calc >= a.threshold end;

  if p_action = 'unlock' then
    insert into streamer_achievements (agency_id, streamer_id, achievement_id, unlocked_at, value_at_unlock, source, manual_by, manual_reason)
    values (v_agency, p_streamer_id, p_achievement_id, now(), coalesce(p_manual_value, v_calc), 'manual', auth.uid(), p_reason)
    on conflict (streamer_id, achievement_id) do update
      -- source fica como estava (auto continua auto): so tira a revogacao
      set revoked_at = null, revoked_by = null, revoke_reason = null,
          manual_by = auth.uid(), manual_reason = p_reason;
  elsif p_action = 'revoke' then
    -- linha fica (com o calculo original); so marca como revogada
    insert into streamer_achievements (agency_id, streamer_id, achievement_id, unlocked_at, value_at_unlock, source, revoked_at, revoked_by, revoke_reason)
    values (v_agency, p_streamer_id, p_achievement_id, now(), v_calc, 'manual', now(), auth.uid(), p_reason)
    on conflict (streamer_id, achievement_id) do update
      set revoked_at = now(), revoked_by = auth.uid(), revoke_reason = p_reason;
  else
    raise exception 'acao invalida';
  end if;

  insert into achievement_adjustments (agency_id, streamer_id, achievement_id, action, reason, calculated_value, calculated_unlocked, manual_value, created_by)
  values (v_agency, p_streamer_id, p_achievement_id, p_action, p_reason, v_calc, v_calc_unlocked, p_manual_value, auth.uid());
end;
$$;
grant execute on function admin_adjust_achievement(uuid, uuid, text, text, numeric) to authenticated;

-- ----------------------------------------------------------------------------
-- 8) App: conquistas (com trilha, icone, origem; revogada = bloqueada)
-- ----------------------------------------------------------------------------
drop function if exists app_my_achievements();
create or replace function app_my_achievements()
returns table (
  id uuid, code text, title text, description text, family text, rule_type text,
  threshold numeric, config jsonb, art_key text, image_url text, sort_order int,
  trail_stage text, trail_order int, icon_key text,
  unlocked_at timestamptz, value_at_unlock numeric, seen boolean, current_value numeric
)
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_agency uuid;
begin
  select p.id, p.agency_id into v_me, v_agency from profiles p where p.auth_user_id = auth.uid() limit 1;
  if v_me is null then return; end if;
  perform evaluate_streamer_achievements(v_me);
  perform evaluate_streamer_month_milestones(v_me);
  return query
    select a.id, a.code, a.title, a.description, a.family, a.rule_type, a.threshold, a.config,
           a.art_key, a.image_url, a.sort_order, a.trail_stage, a.trail_order, a.icon_key,
           case when sa.revoked_at is null then sa.unlocked_at end,
           sa.value_at_unlock,
           (sa.id is null or sa.revoked_at is not null or sa.seen_at is not null),
           achievement_rule_value(v_me, a.rule_type, a.threshold, a.config)
    from achievements a
    left join streamer_achievements sa on sa.achievement_id = a.id and sa.streamer_id = v_me
    where a.agency_id = v_agency and a.is_active
    order by a.family, a.sort_order, a.threshold;
end;
$$;
grant execute on function app_my_achievements() to authenticated;

-- ----------------------------------------------------------------------------
-- 9) App: marcos do mes (com arte do mes) e marcar como vistos
-- ----------------------------------------------------------------------------
create or replace function app_my_month_milestones(p_period text default null)
returns table (
  milestone_id uuid, value numeric, title text, importance int,
  reached boolean, unlocked_at timestamptz, seen boolean, art_url text, is_highest boolean,
  period_key text, current_diamonds numeric
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
           art.image_url, (smm.id is not null and m.value = v_top),
           v_period, v_cur
    from monthly_milestones m
    left join streamer_monthly_milestones smm
      on smm.milestone_id = m.id and smm.streamer_id = v_me and smm.period_key = v_period
    left join monthly_milestone_arts art
      on art.milestone_id = m.id and art.agency_id = v_agency and art.period_key = v_period
    where m.agency_id = v_agency and m.is_active
    order by m.value;
end;
$$;
grant execute on function app_my_month_milestones(text) to authenticated;

create or replace function app_mark_month_milestones_seen(p_milestone_ids uuid[], p_period text default null)
returns void
language sql volatile security definer
set search_path = public
as $$
  update streamer_monthly_milestones smm
  set seen_at = now()
  from profiles p
  where p.auth_user_id = auth.uid()
    and smm.streamer_id = p.id
    and smm.period_key = coalesce(p_period, to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM'))
    and smm.milestone_id = any(p_milestone_ids)
    and smm.seen_at is null;
$$;
grant execute on function app_mark_month_milestones_seen(uuid[], text) to authenticated;

-- ----------------------------------------------------------------------------
-- 10) App: perfil da jornada (brasao) + meta adaptativa. Classificacao interna
--     (journey_stages.key) nao e devolvida; so nome/brasao/textos.
-- ----------------------------------------------------------------------------
create or replace function journey_stage_for(p_streamer_id uuid)
returns uuid
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_agency uuid;
  v_lookback int;
  v_from text;
  st record;
  v_hits int;
  v_default uuid;
begin
  select agency_id into v_agency from profiles where id = p_streamer_id;
  select coalesce((value ->> 'lookback_months')::int, 6) into v_lookback
  from app_settings where agency_id = v_agency and key = 'journey_config' limit 1;
  v_lookback := greatest(coalesce(v_lookback, 6), 1);
  v_from := to_char((now() at time zone 'America/Sao_Paulo') - make_interval(months => v_lookback), 'YYYY-MM');

  for st in
    select * from journey_stages where agency_id = v_agency and is_active order by sort_order desc
  loop
    v_default := st.id;  -- ultimo do loop = menor sort_order
    if st.min_months <= 0 then continue; end if;
    select count(*) into v_hits
    from streamer_month_series(p_streamer_id) s
    where s.period_key >= v_from and s.diamonds >= st.min_value;
    if v_hits >= st.min_months then return st.id; end if;
  end loop;
  return v_default;
end;
$$;

create or replace function app_my_journey()
returns jsonb
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_agency uuid;
  v_name text;
  st journey_stages;
  v_steps numeric[];
  v_horizon numeric;
  v_lookback int;
  v_from text;
  v_cur numeric := 0;
  v_ref numeric := 0;
  v_base numeric;
  v_goal numeric;
  v_second numeric;
  v_unlocked int;
  v_total int;
  v_month_top numeric;
  v_month_count int;
  v_cfg jsonb;
begin
  select p.id, p.agency_id, coalesce(p.display_name, p.tiktok_username) into v_me, v_agency, v_name
  from profiles p where p.auth_user_id = auth.uid() limit 1;
  if v_me is null then return null; end if;

  perform evaluate_streamer_achievements(v_me);
  perform evaluate_streamer_month_milestones(v_me);

  select value into v_cfg from app_settings where agency_id = v_agency and key = 'journey_config' limit 1;
  v_horizon := coalesce((v_cfg ->> 'horizon_value')::numeric, 80000);
  v_lookback := greatest(coalesce((v_cfg ->> 'lookback_months')::int, 6), 1);
  v_from := to_char((now() at time zone 'America/Sao_Paulo') - make_interval(months => v_lookback), 'YYYY-MM');

  select array_agg(value order by value) into v_steps from monthly_milestones where agency_id = v_agency and is_active;
  if v_steps is null then v_steps := array[10000, 20000, 40000, 80000, 150000, 250000, 300000, 500000]; end if;

  select coalesce(max(diamonds) filter (where is_current), 0),
         coalesce(max(diamonds) filter (where not is_current and period_key >= v_from), 0)
  into v_cur, v_ref
  from streamer_month_series(v_me);

  select * into st from journey_stages where id = journey_stage_for(v_me);

  -- meta principal: proximo degrau acima do que ja faz (historico recente ou mes atual)
  v_base := greatest(v_cur, v_ref);
  if st.id is not null and st.goal_mode = 'horizon' and v_cur < v_horizon then
    v_goal := v_horizon;
  else
    select min(s) into v_goal from unnest(v_steps) s where s > v_base;
    if v_goal is null then v_goal := v_steps[array_length(v_steps, 1)]; end if;
  end if;

  if st.id is null or st.secondary_mode = 'none' then
    v_second := null;
  elsif st.secondary_mode = 'horizon' then
    v_second := case when v_goal < v_horizon then v_horizon end;
  else
    select min(s) into v_second from unnest(v_steps) s where s > greatest(v_goal, v_base);
  end if;

  select count(*) filter (where sa.id is not null and sa.revoked_at is null), count(*)
  into v_unlocked, v_total
  from achievements a
  left join streamer_achievements sa on sa.achievement_id = a.id and sa.streamer_id = v_me
  where a.agency_id = v_agency and a.is_active;

  select max(m.value), count(*) into v_month_top, v_month_count
  from streamer_monthly_milestones smm join monthly_milestones m on m.id = smm.milestone_id
  where smm.streamer_id = v_me and smm.period_key = to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM');

  return jsonb_build_object(
    'name', v_name,
    'stage_name', st.name,
    'stage_description', st.description,
    'crest_key', coalesce(st.crest_key, 'prata'),
    'crest_image_url', st.crest_image_url,
    'stage_order', coalesce(st.sort_order, 1),
    'unlocked', v_unlocked,
    'total', v_total,
    'current_diamonds', v_cur,
    'goal_label', coalesce(st.goal_label, 'Seu próximo marco'),
    'goal_value', v_goal,
    'secondary_label', st.secondary_label,
    'secondary_value', v_second,
    'horizon_value', v_horizon,
    'month_top_value', v_month_top,
    'month_count', coalesce(v_month_count, 0)
  );
end;
$$;
grant execute on function app_my_journey() to authenticated;

-- ----------------------------------------------------------------------------
-- 11) Seeds (por agencia). Nada sobrescreve o que o painel ja editou.
-- ----------------------------------------------------------------------------

-- marcos do mes: herda a escada antiga (achievement_progression) + padrao
insert into monthly_milestones (agency_id, value, title, importance)
select a.agency_id, d.value, d.title, d.importance
from (select distinct agency_id from managers where agency_id is not null) a
cross join (values
  (10000, '10K', 1), (20000, '20K', 2), (40000, '40K', 3), (80000, '80K', 4),
  (150000, '150K', 5), (250000, '250K', 6), (300000, '300K', 7), (500000, '500K', 8)
) as d(value, title, importance)
on conflict (agency_id, value) do nothing;

insert into app_settings (agency_id, key, value, updated_at)
select distinct m.agency_id, 'journey_config', '{"lookback_months": 6, "horizon_value": 80000}'::jsonb, now()
from managers m where m.agency_id is not null
on conflict (agency_id, key) do nothing;

insert into journey_stages (agency_id, key, name, description, crest_key, sort_order, min_value, min_months,
                            goal_mode, goal_label, secondary_mode, secondary_label)
select a.agency_id, d.key, d.name, d.description, d.crest_key, d.sort_order, d.min_value, d.min_months,
       d.goal_mode, d.goal_label, d.secondary_mode, d.secondary_label
from (select distinct agency_id from managers where agency_id is not null) a
cross join (values
  ('inicio',          'Primeiros Passos', 'Sua história na MDUCK Agency está começando.', 'prata',   1, 0,      0, 'next_step', 'Seu próximo marco', 'horizon',         'Grande horizonte'),
  ('evolucao',        'Em Evolução',      'Seus resultados já aparecem mês a mês.',       'cristal', 2, 10000,  2, 'next_step', 'Seu próximo marco', 'horizon',         'Grande horizonte'),
  ('consolidado',     'Grande Marco',     'Você já alcança o grande marco de 80K.',       'premium', 3, 80000,  2, 'horizon',   'Seu marco mensal',  'next_after_goal', 'Próximo desafio'),
  ('alto_desempenho', 'Mérito MDUCK',     'Resultados recorrentes acima do grande marco.', 'merito', 4, 150000, 2, 'next_step', 'Seu próximo marco', 'next_after_goal', 'Próximo desafio')
) as d(key, name, description, crest_key, sort_order, min_value, min_months, goal_mode, goal_label, secondary_mode, secondary_label)
on conflict (agency_id, key) do nothing;

-- pontos da trilha: novos
insert into achievements (agency_id, code, title, description, family, rule_type, threshold, config, art_key, sort_order, trail_stage, trail_order, icon_key)
select a.agency_id, d.code, d.title, d.description, d.family, d.rule_type, d.threshold, d.config::jsonb, d.art_key, d.sort_order, d.trail_stage, d.trail_order, d.icon_key
from (select distinct agency_id from managers where agency_id is not null) a
cross join (values
  ('first_live',     'Primeira Live', 'Sua primeira live registrada com a MDUCK Agency.', 'primeira', 'month_days', 1, '{}', 'dias_1', 0, 'primeiros_passos', 1, 'live'),
  ('days_month_5',   '5 Dias',  'Fez live em 5 dias diferentes no mesmo mês.',  'dias', 'month_days', 5,  '{}', 'dias_1', 0, 'primeiros_passos', 2, 'calendar'),
  ('days_month_10',  '10 Dias', 'Fez live em 10 dias diferentes no mesmo mês.', 'dias', 'month_days', 10, '{}', 'dias_1', 0, 'primeiros_passos', 3, 'calendar'),
  ('hours_month_50', '50 Horas', 'Fez 50 horas de live em um único mês.', 'horas', 'month_hours', 50, '{}', 'horas_1', 0, 'dedicacao', 6, 'clock'),
  ('hours_month_80', '80 Horas', 'Fez 80 horas de live em um único mês.', 'horas', 'month_hours', 80, '{}', 'horas_1', 0, 'dedicacao', 7, 'clock'),
  ('month_10k', '10K Diamantes', 'Fechou um mês com pelo menos 10.000 diamantes.', 'mensal', 'month_diamonds', 10000, '{}', 'mensal_1', 0, 'resultados', 9,  'diamond'),
  ('month_20k', '20K Diamantes', 'Fechou um mês com pelo menos 20.000 diamantes.', 'mensal', 'month_diamonds', 20000, '{}', 'mensal_1', 0, 'resultados', 10, 'diamond'),
  ('month_40k', '40K Diamantes', 'Fechou um mês com pelo menos 40.000 diamantes.', 'mensal', 'month_diamonds', 40000, '{}', 'mensal_2', 0, 'resultados', 11, 'diamond'),
  ('combo_80k_22d_100h', 'Grande Marco', '80K diamantes, 22 dias e 100 horas de live no mesmo mês.', 'grande_marco', 'month_combo', 80000, '{"days": 22, "hours": 100}', 'marco_8', 0, 'grande_marco', 13, 'crown'),
  ('merito_placa_1', 'Primeira Placa', 'Primeiro mês no nível do Programa de Mérito da MDUCK Agency.', 'merito', 'month_diamonds', 150000, '{}', 'mensal_7', 0, 'merito', 14, 'plaque')
) as d(code, title, description, family, rule_type, threshold, config, art_key, sort_order, trail_stage, trail_order, icon_key)
on conflict (agency_id, code) do nothing;

-- pontos da trilha: reaproveita conquistas que ja existiam (so se ainda sem posicao)
update achievements set trail_stage = 'primeiros_passos', trail_order = 4, icon_key = 'calendar', title = '15 Dias'
where code = 'days_month_15' and trail_stage is null;
update achievements set trail_stage = 'primeiros_passos', trail_order = 5, icon_key = 'calendar', title = '22 Dias'
where code = 'days_month_22' and trail_stage is null;
update achievements set trail_stage = 'dedicacao', trail_order = 8, icon_key = 'clock', title = '100 Horas'
where code = 'hours_month_100' and trail_stage is null;
update achievements set trail_stage = 'resultados', trail_order = 12, icon_key = 'diamond', title = '80K Diamantes'
where code = 'month_80k' and trail_stage is null;

-- textos antigos com "MDUCK" sozinho -> "MDUCK Agency"
update achievements set description = replace(description, 'com a MDUCK somou', 'com a MDUCK Agency somou')
where description like '%com a MDUCK somou%';
update achievements set description = replace(description, 'com a MDUCK passou', 'com a MDUCK Agency passou')
where description like '%com a MDUCK passou%';

-- ----------------------------------------------------------------------------
-- 12) Calcula ja para todo mundo (historico real) e recarrega a API
-- ----------------------------------------------------------------------------
do $$
declare p record;
begin
  for p in select id from profiles loop
    perform evaluate_streamer_achievements(p.id);
    perform evaluate_streamer_month_milestones(p.id);
  end loop;
end $$;

notify pgrst, 'reload schema';

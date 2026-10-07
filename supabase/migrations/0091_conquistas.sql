-- ============================================================================
-- Inventario > CONQUISTAS (automaticas). A "Jornada MDUCK" (manual) continua
-- em streamer_inventory_entries (0059/0090) -- sao coisas diferentes:
--   Conquistas  = o que o streamer conquistou (calculado pelo sistema)
--   Jornada     = o que a MDUCK Agency fez pelo streamer (registrado pela equipe)
--
-- Fontes de dados (as mesmas do resto do sistema, nada novo):
--   streamer_stats  diamonds / hours_live / days_live do MES ATUAL
--   monthly_stats   meses fechados (period_key 'AAAA-MM'), gravados pela
--                   Importacao TikTok
--
-- Regras (rule_type) -- todas configuraveis por linha em achievements:
--   total_diamonds               soma historica de diamantes >= threshold
--   month_diamonds               algum mes com diamantes >= threshold
--   consecutive_months_diamonds  config.months meses SEGUIDOS >= threshold
--   month_hours                  algum mes com horas de live >= threshold
--   total_hours                  soma historica de horas >= threshold
--   month_days                   algum mes com dias de live >= threshold
--
-- Desbloqueio automatico e idempotente:
--   * streamer_achievements tem unique (streamer_id, achievement_id) e o
--     insert usa "on conflict do nothing": a primeira data nunca e trocada.
--   * roda sozinho quando a importacao grava streamer_stats/monthly_stats
--     (triggers abaixo) e tambem quando o app abre a tela (reforco).
--   * a data de desbloqueio e o fim do mes em que o marco foi atingido (meses
--     fechados) ou o momento do calculo (mes atual). Desbloqueios de meses ja
--     fechados entram como "vistos" (sem celebracao no app); so os do mes
--     atual disparam a celebracao.
--
-- Proximo marco (progressao mensal): app_settings 'achievement_progression'
-- (lista de valores, editavel no painel). Padrao 80K -> 150K -> 250K -> 350K
-- -> 500K -> 800K -> 1M -> 1,2M.
--
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

-- Se ja existir uma tabela antiga "achievements"/"streamer_achievements" sem
-- agency_id (de outro modelo), ela e preservada com sufixo _legado.
do $$
declare
  t text;
  v_new text;
  v_cols text[];
  i record;
begin
  foreach t in array array['streamer_achievements', 'achievements'] loop
    v_cols := case t
      when 'achievements' then array['agency_id', 'code', 'family', 'rule_type', 'threshold', 'config', 'art_key', 'image_url', 'sort_order', 'is_active']
      else array['agency_id', 'streamer_id', 'achievement_id', 'unlocked_at', 'value_at_unlock', 'period_key', 'seen_at', 'source']
    end;
    if to_regclass('public.' || t) is not null and (
      select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = t and column_name = any(v_cols)
    ) < array_length(v_cols, 1) then
      v_new := t || '_legado';
      while to_regclass('public.' || v_new) is not null loop
        v_new := v_new || '_x';
      end loop;
      execute format('alter table public.%I rename to %I', t, v_new);
      -- indices/constraints (ex.: achievements_pkey) tambem ganham sufixo,
      -- pra nao colidir com os da tabela nova.
      for i in
        select ic.relname from pg_index x
        join pg_class ic on ic.oid = x.indexrelid
        where x.indrelid = ('public.' || v_new)::regclass
      loop
        execute format('alter index public.%I rename to %I', i.relname, left(i.relname, 40) || '_' || substr(md5(random()::text), 1, 6) || '_legado');
      end loop;
    end if;
  end loop;
end $$;

create table if not exists achievements (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  code text not null,
  title text not null,
  description text not null,
  family text not null check (family in ('marco', 'mensal', 'consistencia', 'horas', 'dias')),
  rule_type text not null check (rule_type in (
    'total_diamonds', 'month_diamonds', 'consecutive_months_diamonds', 'month_hours', 'total_hours', 'month_days'
  )),
  threshold numeric not null,
  config jsonb not null default '{}'::jsonb,
  art_key text,
  image_url text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agency_id, code)
);

comment on table achievements is 'Definicao das conquistas automaticas (Inventario > Conquistas). art_key = arte desenhada no app; image_url = arte enviada pelo painel (tem prioridade).';

create table if not exists streamer_achievements (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id) on delete cascade,
  achievement_id uuid not null references achievements(id) on delete cascade,
  unlocked_at timestamptz not null,
  value_at_unlock numeric,
  period_key text,
  metadata jsonb not null default '{}'::jsonb,
  seen_at timestamptz,
  source text not null default 'auto' check (source in ('auto', 'manual')),
  created_at timestamptz not null default now(),
  unique (streamer_id, achievement_id)
);
create index if not exists idx_streamer_achievements_achievement on streamer_achievements(achievement_id);

alter table achievements enable row level security;
alter table streamer_achievements enable row level security;

drop policy if exists "achievements_agency" on achievements;
create policy "achievements_agency" on achievements
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "streamer_achievements_agency" on streamer_achievements;
create policy "streamer_achievements_agency" on streamer_achievements
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- ============================================================================
-- Serie mensal do streamer: meses fechados + mes atual (sem contar duas vezes)
-- ============================================================================
drop function if exists app_my_achievements();
drop function if exists app_my_next_milestone();
drop function if exists app_mark_achievements_seen(uuid[]);
drop function if exists evaluate_agency_achievements();
drop function if exists evaluate_streamer_achievements(uuid);
drop function if exists achievement_rule_value(uuid, text, numeric, jsonb);
drop function if exists streamer_month_series(uuid);

create or replace function streamer_month_series(p_streamer_id uuid)
returns table (period_key text, diamonds numeric, hours numeric, days numeric, period_end timestamptz, is_current boolean)
language sql stable security definer
set search_path = public
as $$
  with cur as (select to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM') as k)
  select m.period_key,
         coalesce(m.diamonds, 0)::numeric,
         coalesce(m.hours_live, 0)::numeric,
         coalesce(m.days_live, 0)::numeric,
         ((to_date(m.period_key || '-01', 'YYYY-MM-DD') + interval '1 month' - interval '1 second')::timestamp
            at time zone 'America/Sao_Paulo'),
         false
  from monthly_stats m, cur
  where m.streamer_id = p_streamer_id and m.period_key < cur.k
  union all
  select cur.k,
         coalesce(s.diamonds, 0)::numeric,
         coalesce(s.hours_live, 0)::numeric,
         coalesce(s.days_live, 0)::numeric,
         now(),
         true
  from streamer_stats s, cur
  where s.streamer_id = p_streamer_id
  order by 1;
$$;

-- Valor atual de cada regra (pro progresso das bloqueadas).
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
  elsif p_rule_type = 'consecutive_months_diamonds' then
    -- maior sequencia de meses seguidos acima do threshold
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

-- ============================================================================
-- Desbloqueio automatico (idempotente). Devolve quantas foram desbloqueadas.
-- ============================================================================
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

    for r in select * from streamer_month_series(p_streamer_id) loop
      if a.rule_type = 'total_diamonds' then
        v_acc := v_acc + r.diamonds;
        if v_acc >= a.threshold then v_found := true; v_key := r.period_key; v_end := r.period_end; v_is_current := r.is_current; exit; end if;
      elsif a.rule_type = 'total_hours' then
        v_acc := v_acc + r.hours;
        if v_acc >= a.threshold then v_found := true; v_key := r.period_key; v_end := r.period_end; v_is_current := r.is_current; exit; end if;
      elsif a.rule_type = 'month_diamonds' then
        v_acc := r.diamonds;
        if r.diamonds >= a.threshold then v_found := true; v_key := r.period_key; v_end := r.period_end; v_is_current := r.is_current; exit; end if;
      elsif a.rule_type = 'month_hours' then
        v_acc := r.hours;
        if r.hours >= a.threshold then v_found := true; v_key := r.period_key; v_end := r.period_end; v_is_current := r.is_current; exit; end if;
      elsif a.rule_type = 'month_days' then
        v_acc := r.days;
        if r.days >= a.threshold then v_found := true; v_key := r.period_key; v_end := r.period_end; v_is_current := r.is_current; exit; end if;
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
        if v_streak >= v_needed then v_found := true; v_key := r.period_key; v_end := r.period_end; v_is_current := r.is_current; exit; end if;
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

-- Recalcula todos os streamers da agencia do gestor logado (botao no painel).
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
  end loop;
  return v_total;
end;
$$;

-- ============================================================================
-- Triggers: sempre que a importacao atualiza os numeros, recalcula aquele
-- streamer. Nunca derruba a importacao se algo falhar aqui.
-- ============================================================================
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
  return new;
end;
$$;

drop trigger if exists trg_streamer_stats_achievements on streamer_stats;
create trigger trg_streamer_stats_achievements
  after insert or update on streamer_stats
  for each row execute function trg_evaluate_achievements();

drop trigger if exists trg_monthly_stats_achievements on monthly_stats;
create trigger trg_monthly_stats_achievements
  after insert or update on monthly_stats
  for each row execute function trg_evaluate_achievements();

-- ============================================================================
-- Funcoes do app
-- ============================================================================

-- Todas as conquistas ativas da agencia do streamer logado, com o estado
-- dele (recalcula antes, como reforco) e o valor atual pra barra de progresso.
create or replace function app_my_achievements()
returns table (
  id uuid,
  code text,
  title text,
  description text,
  family text,
  rule_type text,
  threshold numeric,
  config jsonb,
  art_key text,
  image_url text,
  sort_order int,
  unlocked_at timestamptz,
  value_at_unlock numeric,
  seen boolean,
  current_value numeric
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
  return query
    select a.id, a.code, a.title, a.description, a.family, a.rule_type, a.threshold, a.config,
           a.art_key, a.image_url, a.sort_order,
           sa.unlocked_at, sa.value_at_unlock, (sa.id is null or sa.seen_at is not null),
           achievement_rule_value(v_me, a.rule_type, a.threshold, a.config)
    from achievements a
    left join streamer_achievements sa on sa.achievement_id = a.id and sa.streamer_id = v_me
    where a.agency_id = v_agency and a.is_active
    order by a.family, a.sort_order, a.threshold;
end;
$$;

-- Marca como vistas (depois da celebracao no app).
create or replace function app_mark_achievements_seen(p_ids uuid[])
returns void
language sql volatile security definer
set search_path = public
as $$
  update streamer_achievements sa
  set seen_at = now()
  from profiles p
  where p.auth_user_id = auth.uid()
    and sa.streamer_id = p.id
    and sa.achievement_id = any(p_ids)
    and sa.seen_at is null;
$$;

-- Proximo marco do mes: parte do que o streamer fez no mes anterior.
create or replace function app_my_next_milestone()
returns table (prev_month_diamonds numeric, current_diamonds numeric, target numeric, next_target numeric, reached boolean)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_agency uuid;
  v_steps numeric[];
  v_prev numeric;
  v_cur numeric;
  v_target numeric;
  v_next numeric;
  v_setting jsonb;
  v_prev_key text := to_char((now() at time zone 'America/Sao_Paulo') - interval '1 month', 'YYYY-MM');
begin
  select p.id, p.agency_id into v_me, v_agency from profiles p where p.auth_user_id = auth.uid() limit 1;
  if v_me is null then return; end if;

  select value into v_setting from app_settings where agency_id = v_agency and key = 'achievement_progression' limit 1;
  if v_setting is not null and jsonb_typeof(v_setting) = 'array' and jsonb_array_length(v_setting) > 0 then
    select array_agg(x::numeric order by x::numeric) into v_steps from jsonb_array_elements_text(v_setting) x;
  else
    v_steps := array[80000, 150000, 250000, 350000, 500000, 800000, 1000000, 1200000];
  end if;

  select coalesce(diamonds, 0) into v_prev from monthly_stats where streamer_id = v_me and period_key = v_prev_key;
  v_prev := coalesce(v_prev, 0);
  select coalesce(diamonds, 0) into v_cur from streamer_stats where streamer_id = v_me;
  v_cur := coalesce(v_cur, 0);

  -- alvo = primeiro valor da escada acima do que foi feito no mes anterior
  select min(s) into v_target from unnest(v_steps) s where s > v_prev;
  if v_target is null then v_target := v_steps[array_length(v_steps, 1)]; end if;
  select min(s) into v_next from unnest(v_steps) s where s > v_target;

  prev_month_diamonds := v_prev;
  current_diamonds := v_cur;
  target := v_target;
  next_target := v_next;
  reached := v_cur >= v_target;
  return next;
end;
$$;

grant execute on function app_my_achievements() to authenticated;
grant execute on function app_mark_achievements_seen(uuid[]) to authenticated;
grant execute on function app_my_next_milestone() to authenticated;
grant execute on function evaluate_agency_achievements() to authenticated;

-- ============================================================================
-- Conquistas iniciais (pra cada agencia que ainda nao tem)
-- ============================================================================
insert into achievements (agency_id, code, title, description, family, rule_type, threshold, config, art_key, sort_order)
select a.agency_id, d.code, d.title, d.description, d.family, d.rule_type, d.threshold, d.config::jsonb, d.art_key, d.sort_order
from (select distinct agency_id from managers where agency_id is not null) a
cross join (values
  -- marcos historicos (soma de todos os meses)
  ('total_80k',   'Primeiros 80K',   'Sua história com a MDUCK Agency somou 80.000 diamantes.',      'marco', 'total_diamonds', 80000,   '{}', 'marco_1', 1),
  ('total_150k',  'Primeiros 150K',  'Sua história com a MDUCK Agency somou 150.000 diamantes.',     'marco', 'total_diamonds', 150000,  '{}', 'marco_2', 2),
  ('total_250k',  'Primeiros 250K',  'Sua história com a MDUCK Agency somou 250.000 diamantes.',     'marco', 'total_diamonds', 250000,  '{}', 'marco_3', 3),
  ('total_350k',  'Primeiros 350K',  'Sua história com a MDUCK Agency somou 350.000 diamantes.',     'marco', 'total_diamonds', 350000,  '{}', 'marco_4', 4),
  ('total_500k',  'Primeiros 500K',  'Meio milhão de diamantes na sua história.',             'marco', 'total_diamonds', 500000,  '{}', 'marco_5', 5),
  ('total_800k',  'Primeiros 800K',  'Sua história com a MDUCK Agency somou 800.000 diamantes.',     'marco', 'total_diamonds', 800000,  '{}', 'marco_6', 6),
  ('total_1m',    'Primeiro 1M',     'Seu primeiro milhão de diamantes.',                     'marco', 'total_diamonds', 1000000, '{}', 'marco_7', 7),
  ('total_1_2m',  'Primeiro 1,2M',   'Sua história com a MDUCK Agency passou de 1,2 milhão de diamantes.', 'marco', 'total_diamonds', 1200000, '{}', 'marco_8', 8),
  -- desempenho num unico mes
  ('month_80k',   '80K em um mês',   'Fechou um mês com pelo menos 80.000 diamantes.',        'mensal', 'month_diamonds', 80000,   '{}', 'mensal_1', 1),
  ('month_150k',  '150K em um mês',  'Fechou um mês com pelo menos 150.000 diamantes.',       'mensal', 'month_diamonds', 150000,  '{}', 'mensal_2', 2),
  ('month_250k',  '250K em um mês',  'Fechou um mês com pelo menos 250.000 diamantes.',       'mensal', 'month_diamonds', 250000,  '{}', 'mensal_3', 3),
  ('month_350k',  '350K em um mês',  'Fechou um mês com pelo menos 350.000 diamantes.',       'mensal', 'month_diamonds', 350000,  '{}', 'mensal_4', 4),
  ('month_500k',  '500K em um mês',  'Fechou um mês com pelo menos 500.000 diamantes.',       'mensal', 'month_diamonds', 500000,  '{}', 'mensal_5', 5),
  ('month_800k',  '800K em um mês',  'Fechou um mês com pelo menos 800.000 diamantes.',       'mensal', 'month_diamonds', 800000,  '{}', 'mensal_6', 6),
  ('month_1m',    '1M em um mês',    'Um milhão de diamantes em um único mês.',               'mensal', 'month_diamonds', 1000000, '{}', 'mensal_7', 7),
  -- consistencia
  ('streak_3x80k',  '3 meses acima de 80K',  'Três meses seguidos com pelo menos 80.000 diamantes.',  'consistencia', 'consecutive_months_diamonds', 80000,  '{"months": 3}', 'consistencia_1', 1),
  ('streak_6x80k',  '6 meses acima de 80K',  'Seis meses seguidos com pelo menos 80.000 diamantes.',  'consistencia', 'consecutive_months_diamonds', 80000,  '{"months": 6}', 'consistencia_2', 2),
  ('streak_3x150k', '3 meses acima de 150K', 'Três meses seguidos com pelo menos 150.000 diamantes.', 'consistencia', 'consecutive_months_diamonds', 150000, '{"months": 3}', 'consistencia_3', 3),
  -- horas de live
  ('hours_month_60',  '60 horas em um mês',  'Fez 60 horas de live em um único mês.',        'horas', 'month_hours', 60,   '{}', 'horas_1', 1),
  ('hours_month_100', '100 horas em um mês', 'Fez 100 horas de live em um único mês.',       'horas', 'month_hours', 100,  '{}', 'horas_2', 2),
  ('hours_total_500', '500 horas de live',   'Somou 500 horas de live na sua história.',     'horas', 'total_hours', 500,  '{}', 'horas_3', 3),
  ('hours_total_1000','1.000 horas de live', 'Somou 1.000 horas de live na sua história.',   'horas', 'total_hours', 1000, '{}', 'horas_4', 4),
  -- dias de live
  ('days_month_15', '15 dias no mês', 'Fez live em 15 dias diferentes no mesmo mês.', 'dias', 'month_days', 15, '{}', 'dias_1', 1),
  ('days_month_22', '22 dias no mês', 'Fez live em 22 dias diferentes no mesmo mês.', 'dias', 'month_days', 22, '{}', 'dias_2', 2),
  ('days_month_28', '28 dias no mês', 'Fez live em 28 dias diferentes no mesmo mês.', 'dias', 'month_days', 28, '{}', 'dias_3', 3)
) as d(code, title, description, family, rule_type, threshold, config, art_key, sort_order)
on conflict (agency_id, code) do nothing;

-- escada do proximo marco (so se a agencia ainda nao configurou)
insert into app_settings (agency_id, key, value, updated_at)
select distinct m.agency_id, 'achievement_progression', '[80000,150000,250000,350000,500000,800000,1000000,1200000]'::jsonb, now()
from managers m
where m.agency_id is not null
on conflict (agency_id, key) do nothing;

-- calcula o historico de todo mundo agora (desbloqueios antigos entram como vistos)
do $$
declare p record;
begin
  for p in select id from profiles loop
    perform evaluate_streamer_achievements(p.id);
  end loop;
end $$;

notify pgrst, 'reload schema';

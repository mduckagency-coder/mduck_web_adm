-- ============================================================================
-- Nova estrutura da Jornada (sem Trilha):
--   1. Marcos do Mes: 10K 20K 40K 80K 150K 250K 350K 500K 800K 1M 1,2M 1,6M
--      (300K vira 350K; 80K continua o grande marco do mes)
--   2. Conquistas = historico permanente, revisado:
--      Diamantes (primeira vez de cada marco), Constancia (3/6/12 meses
--      seguidos acima de 80K e 150K), Horas acumuladas (100/500/1000/2500/5000),
--      Frequencia (22 dias, 100 horas, 22 dias + 100 horas no mesmo mes) e os
--      combos. Conquistas basicas (Primeira Live, 5/10/15 dias...) saem do app
--      (ficam desativadas, nada e apagado; da pra reativar no painel).
--   3. Trilha removida: limpa trail_stage/trail_order.
--   4. Constancia: indicador automatico (journey_constancy).
--   5. Primeiros 90 dias: fase de desenvolvimento a partir do acesso ao app.
--   6. app_my_journey devolve: metas profissionais (22 dias / 100 h / 80K),
--      constancia, primeiros 90 dias, recorde e horas acumuladas.
--
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Marcos do Mes
-- ----------------------------------------------------------------------------
-- 300K -> 350K (mantem o id e as artes ja enviadas). Quem tinha 300K mas
-- menos de 350K no mes perde so esse degrau (o resto do historico fica).
update monthly_milestones m
set value = 350000, title = '350K', updated_at = now()
where m.value = 300000
  and not exists (select 1 from monthly_milestones x where x.agency_id = m.agency_id and x.value = 350000);
delete from streamer_monthly_milestones smm
using monthly_milestones m
where m.id = smm.milestone_id and m.value = 350000 and coalesce(smm.value_at_unlock, 0) < 350000;
delete from monthly_milestones where value = 300000;

insert into monthly_milestones (agency_id, value, title, importance)
select a.agency_id, d.value, d.title, d.importance
from (select distinct agency_id from managers where agency_id is not null) a
cross join (values
  (10000, '10K', 1), (20000, '20K', 2), (40000, '40K', 3), (80000, '80K', 4),
  (150000, '150K', 5), (250000, '250K', 5), (350000, '350K', 6), (500000, '500K', 6),
  (800000, '800K', 7), (1000000, '1M', 7), (1200000, '1,2M', 8), (1600000, '1,6M', 8)
) as d(value, title, importance)
on conflict (agency_id, value) do update set title = excluded.title, importance = excluded.importance, is_active = true, updated_at = now();

-- ----------------------------------------------------------------------------
-- 2) Conquistas
-- ----------------------------------------------------------------------------
-- regra month_combo: threshold 1 = sem exigencia de diamantes (so dias + horas)
-- (o calculo existente ja trata: diamantes >= 1 sempre que houve live)

-- 2a) sem relevancia -> desativadas (historico preservado)
update achievements set is_active = false, updated_at = now()
where code in ('first_live', 'days_month_5', 'days_month_10', 'days_month_15', 'hours_month_50', 'hours_month_60', 'hours_month_80',
               'total_80k', 'total_150k', 'total_250k', 'total_350k', 'total_500k', 'total_800k', 'total_1m', 'total_1_2m');

-- 2b) cria/atualiza o catalogo novo
insert into achievements (agency_id, code, title, description, family, rule_type, threshold, config, art_key, icon_key, sort_order, is_active)
select a.agency_id, d.code, d.title, d.description, d.family, d.rule_type, d.threshold, d.config::jsonb, d.art_key, d.icon_key, d.sort_order, true
from (select distinct agency_id from managers where agency_id is not null) a
cross join (values
  -- DIAMANTES: primeira vez que alcancou cada marco no mes
  ('month_10k',   'Primeiro 10K',   'A primeira vez que você fez 10.000 diamantes em um mês.',     'mensal', 'month_diamonds', 10000,   '{}', 'mensal_1', 'diamond', 1),
  ('month_20k',   'Primeiro 20K',   'A primeira vez que você fez 20.000 diamantes em um mês.',     'mensal', 'month_diamonds', 20000,   '{}', 'mensal_1', 'diamond', 2),
  ('month_40k',   'Primeiro 40K',   'A primeira vez que você fez 40.000 diamantes em um mês.',     'mensal', 'month_diamonds', 40000,   '{}', 'mensal_2', 'diamond', 3),
  ('month_80k',   'Primeiro 80K',   'A primeira vez que você bateu o grande marco de 80.000 diamantes em um mês.', 'mensal', 'month_diamonds', 80000, '{}', 'mensal_3', 'diamond', 4),
  ('month_150k',  'Primeiro 150K',  'A primeira vez que você fez 150.000 diamantes em um mês.',    'mensal', 'month_diamonds', 150000,  '{}', 'mensal_4', 'diamond', 5),
  ('month_250k',  'Primeiro 250K',  'A primeira vez que você fez 250.000 diamantes em um mês.',    'mensal', 'month_diamonds', 250000,  '{}', 'mensal_4', 'diamond', 6),
  ('month_350k',  'Primeiro 350K',  'A primeira vez que você fez 350.000 diamantes em um mês.',    'mensal', 'month_diamonds', 350000,  '{}', 'mensal_5', 'diamond', 7),
  ('month_500k',  'Primeiro 500K',  'A primeira vez que você fez 500.000 diamantes em um mês.',    'mensal', 'month_diamonds', 500000,  '{}', 'mensal_5', 'diamond', 8),
  ('month_800k',  'Primeiro 800K',  'A primeira vez que você fez 800.000 diamantes em um mês.',    'mensal', 'month_diamonds', 800000,  '{}', 'mensal_6', 'diamond', 9),
  ('month_1m',    'Primeiro 1M',    'A primeira vez que você fez 1 milhão de diamantes em um mês.', 'mensal', 'month_diamonds', 1000000, '{}', 'mensal_7', 'diamond', 10),
  ('month_1_2m',  'Primeiro 1,2M',  'A primeira vez que você fez 1,2 milhão de diamantes em um mês.', 'mensal', 'month_diamonds', 1200000, '{}', 'mensal_7', 'diamond', 11),
  ('month_1_6m',  'Primeiro 1,6M',  'A primeira vez que você fez 1,6 milhão de diamantes em um mês.', 'mensal', 'month_diamonds', 1600000, '{}', 'mensal_7', 'diamond', 12),
  -- CONSTANCIA: meses seguidos no mesmo nivel
  ('streak_3x80k',   '3 meses acima de 80K',   'Três meses seguidos com pelo menos 80.000 diamantes.',  'consistencia', 'consecutive_months_diamonds', 80000,  '{"months": 3}',  'consistencia_1', 'laurel', 1),
  ('streak_6x80k',   '6 meses acima de 80K',   'Seis meses seguidos com pelo menos 80.000 diamantes.',  'consistencia', 'consecutive_months_diamonds', 80000,  '{"months": 6}',  'consistencia_2', 'laurel', 2),
  ('streak_12x80k',  '12 meses acima de 80K',  'Doze meses seguidos com pelo menos 80.000 diamantes.',  'consistencia', 'consecutive_months_diamonds', 80000,  '{"months": 12}', 'consistencia_3', 'laurel', 3),
  ('streak_3x150k',  '3 meses acima de 150K',  'Três meses seguidos com pelo menos 150.000 diamantes.', 'consistencia', 'consecutive_months_diamonds', 150000, '{"months": 3}',  'consistencia_3', 'laurel', 4),
  ('streak_6x150k',  '6 meses acima de 150K',  'Seis meses seguidos com pelo menos 150.000 diamantes.', 'consistencia', 'consecutive_months_diamonds', 150000, '{"months": 6}',  'consistencia_3', 'laurel', 5),
  ('streak_12x150k', '12 meses acima de 150K', 'Doze meses seguidos com pelo menos 150.000 diamantes.', 'consistencia', 'consecutive_months_diamonds', 150000, '{"months": 12}', 'consistencia_3', 'laurel', 6),
  -- HORAS acumuladas na trajetoria
  ('hours_total_100',  'Primeiras 100 horas',    'Suas primeiras 100 horas de live na MDUCK Agency.', 'horas', 'total_hours', 100,  '{}', 'horas_1', 'clock', 1),
  ('hours_total_500',  '500 horas acumuladas',   'Somou 500 horas de live na sua trajetória.',        'horas', 'total_hours', 500,  '{}', 'horas_2', 'hourglass', 2),
  ('hours_total_1000', '1.000 horas acumuladas', 'Somou 1.000 horas de live na sua trajetória.',      'horas', 'total_hours', 1000, '{}', 'horas_3', 'hourglass', 3),
  ('hours_total_2500', '2.500 horas acumuladas', 'Somou 2.500 horas de live na sua trajetória.',      'horas', 'total_hours', 2500, '{}', 'horas_4', 'flame', 4),
  ('hours_total_5000', '5.000 horas acumuladas', 'Somou 5.000 horas de live na sua trajetória.',      'horas', 'total_hours', 5000, '{}', 'horas_4', 'flame', 5),
  -- FREQUENCIA: meses de dedicacao profissional
  ('days_month_22',   '22 dias de live em um mês',  'Fez live em 22 dias diferentes no mesmo mês.', 'dias', 'month_days',  22,  '{}', 'dias_3', 'calendar', 1),
  ('hours_month_100', '100 horas de live em um mês', 'Fez 100 horas de live em um único mês.',      'dias', 'month_hours', 100, '{}', 'horas_2', 'flame', 2),
  ('combo_22d_100h',  'Mês profissional',           '22 dias e 100 horas de live no mesmo mês: um mês completo de constância profissional.', 'grande_marco', 'month_combo', 1, '{"days": 22, "hours": 100}', 'marco_7', 'laurel', 1),
  ('combo_80k_22d_100h', 'Grande Marco completo',  '80K diamantes, 22 dias e 100 horas de live no mesmo mês.', 'grande_marco', 'month_combo', 80000, '{"days": 22, "hours": 100}', 'marco_8', 'crown', 2)
) as d(code, title, description, family, rule_type, threshold, config, art_key, icon_key, sort_order)
on conflict (agency_id, code) do update
  set title = excluded.title,
      description = excluded.description,
      family = excluded.family,
      icon_key = excluded.icon_key,
      sort_order = excluded.sort_order,
      is_active = true,
      updated_at = now();
-- (threshold/regra de quem ja existia nao muda: datas de desbloqueio preservadas)

-- ----------------------------------------------------------------------------
-- 3) Trilha removida
-- ----------------------------------------------------------------------------
update achievements set trail_stage = null, trail_order = null where trail_stage is not null or trail_order is not null;

-- ----------------------------------------------------------------------------
-- 4) Constancia (indicador vivo e automatico)
--    Considera: dias e horas do mes (projetados pelo ritmo ate agora),
--    comparacao com o mes anterior, dias desde a ultima live e retomada.
--    Estados: forte | evolucao | estavel | retomando | alerta
-- ----------------------------------------------------------------------------
create or replace function journey_constancy(p_streamer_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_today date := (now() at time zone 'America/Sao_Paulo')::date;
  v_day int := extract(day from (now() at time zone 'America/Sao_Paulo'))::int;
  v_month_days int := extract(day from (date_trunc('month', now() at time zone 'America/Sao_Paulo') + interval '1 month - 1 day'))::int;
  v_prev_key text := to_char((now() at time zone 'America/Sao_Paulo') - interval '1 month', 'YYYY-MM');
  v_days numeric := 0;
  v_hours numeric := 0;
  v_pdays numeric := 0;
  v_phours numeric := 0;
  v_last date;
  v_gap int;
  v_elapsed numeric;
  v_proj_days numeric;
  v_proj_hours numeric;
  v_state text;
  v_label text;
  v_msg text;
  v_intensity numeric;
begin
  select coalesce(days_live, 0), coalesce(hours_live, 0) into v_days, v_hours from streamer_stats where streamer_id = p_streamer_id;
  v_days := coalesce(v_days, 0);
  v_hours := coalesce(v_hours, 0);
  select coalesce(days_live, 0), coalesce(hours_live, 0) into v_pdays, v_phours from monthly_stats where streamer_id = p_streamer_id and period_key = v_prev_key;
  v_pdays := coalesce(v_pdays, 0);
  v_phours := coalesce(v_phours, 0);
  select (last_live_at at time zone 'America/Sao_Paulo')::date into v_last from profiles where id = p_streamer_id;
  v_gap := case when v_last is null then 999 else v_today - v_last end;

  v_elapsed := greatest(v_day, 5);
  v_proj_days := least(v_days * v_month_days / v_elapsed, v_month_days);
  v_proj_hours := v_hours * v_month_days / v_elapsed;
  v_intensity := least(1, least(v_proj_days / 22, 1) * 0.5 + least(v_proj_hours / 100, 1) * 0.5);

  if v_gap >= 7 or (v_days = 0 and v_day >= 7) then
    v_state := 'alerta';
    v_label := 'Chama baixa';
    v_msg := 'Alguns dias sem live. Uma live hoje já reacende sua constância.';
    v_intensity := 0.15;
  elsif v_gap <= 3 and v_pdays <= 4 and v_days between 1 and 5 then
    v_state := 'retomando';
    v_label := 'Retomando';
    v_msg := 'Que bom te ver de volta! Mantenha as lives nos próximos dias.';
    v_intensity := greatest(v_intensity, 0.35);
  elsif v_proj_days >= 18 and v_proj_hours >= 80 then
    v_state := 'forte';
    v_label := 'Constância forte';
    v_msg := 'Você está no ritmo de um mês profissional.';
  elsif v_proj_days > v_pdays * 1.1 or v_proj_hours > v_phours * 1.1 then
    v_state := 'evolucao';
    v_label := 'Em evolução';
    v_msg := 'Sua frequência está subindo em relação ao mês passado.';
  elsif v_proj_days < v_pdays * 0.8 and v_proj_days < 14 then
    v_state := 'alerta';
    v_label := 'Chama baixa';
    v_msg := 'Hora de reacender: programe suas próximas lives na semana.';
  else
    v_state := 'estavel';
    v_label := 'Ritmo estável';
    v_msg := 'Você está mantendo o ritmo. Rumo aos 22 dias e 100 horas.';
  end if;

  return jsonb_build_object(
    'state', v_state,
    'label', v_label,
    'message', v_msg,
    'intensity', round(v_intensity, 2),
    'days_since_last_live', case when v_gap = 999 then null else v_gap end
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 5) Primeiros 90 dias (a partir do acesso ao app)
-- ----------------------------------------------------------------------------
create or replace function journey_onboarding(p_streamer_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public, auth
as $$
declare
  v_agency uuid;
  v_start timestamptz;
  v_total int;
  v_day int;
  v_cfg jsonb;
  v_phases jsonb;
  v_phase jsonb;
  i int;
begin
  select p.agency_id, coalesce(u.created_at, p.joined_at::timestamptz)
  into v_agency, v_start
  from profiles p left join auth.users u on u.id = p.auth_user_id
  where p.id = p_streamer_id;
  if v_start is null then return jsonb_build_object('active', false); end if;

  select value into v_cfg from app_settings where agency_id = v_agency and key = 'journey_config' limit 1;
  v_total := greatest(coalesce((v_cfg ->> 'onboarding_days')::int, 90), 1);
  v_day := ((now() at time zone 'America/Sao_Paulo')::date - (v_start at time zone 'America/Sao_Paulo')::date) + 1;
  if v_day > v_total or v_day < 1 then return jsonb_build_object('active', false); end if;

  v_phases := coalesce(v_cfg -> 'onboarding_phases', jsonb_build_array(
    jsonb_build_object('until', 30, 'title', 'Construindo a rotina',
      'tips', jsonb_build_array('Faça live em pelo menos 3 dias por semana.', 'Escolha horários fixos para o seu público te encontrar.', 'Busque lives de pelo menos 1h30.')),
    jsonb_build_object('until', 60, 'title', 'Ganhando ritmo',
      'tips', jsonb_build_array('Suba para 4 a 5 dias de live por semana.', 'Mire em lives de 2 horas ou mais.', 'Divulgue seus horários no perfil e nos stories.')),
    jsonb_build_object('until', 90, 'title', 'Rotina profissional',
      'tips', jsonb_build_array('Mire nos 22 dias de live no mês.', 'Some 100 horas ao vivo no mês.', 'Use os Marcos do Mês como degraus até os 80K.'))
  ));
  v_phase := v_phases -> (jsonb_array_length(v_phases) - 1);
  for i in 0..jsonb_array_length(v_phases) - 1 loop
    if v_day <= coalesce((v_phases -> i ->> 'until')::int, v_total) then
      v_phase := v_phases -> i;
      exit;
    end if;
  end loop;

  return jsonb_build_object(
    'active', true,
    'day', v_day,
    'total', v_total,
    'phase_title', v_phase ->> 'title',
    'tips', coalesce(v_phase -> 'tips', '[]'::jsonb)
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- 6) Resumo da Jornada pro app
-- ----------------------------------------------------------------------------
create or replace function app_my_journey()
returns jsonb
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_me uuid;
  v_agency uuid;
  v_name text;
  v_avatar text;
  v_custom_days int;
  v_custom_hours numeric;
  v_days_target numeric;
  v_hours_target numeric;
  v_diamond_target numeric;
  st journey_stages;
  v_unlocked int;
  v_total int;
  v_cur record;
  v_record_value numeric;
  v_record_period text;
  v_total_hours numeric;
  v_cfg jsonb;
begin
  select p.id, p.agency_id, coalesce(nullif(p.tiktok_username, ''), p.display_name), p.avatar_url, p.custom_days_target, p.custom_hours_target
  into v_me, v_agency, v_name, v_avatar, v_custom_days, v_custom_hours
  from profiles p where p.auth_user_id = auth.uid() limit 1;
  if v_me is null then return null; end if;

  perform evaluate_streamer_achievements(v_me);
  perform evaluate_streamer_month_milestones(v_me);

  select value into v_cfg from app_settings where agency_id = v_agency and key = 'journey_config' limit 1;
  -- metas profissionais: nunca reduzidas pelo historico
  v_days_target := coalesce(v_custom_days, (select (value #>> '{}')::numeric from app_settings where agency_id = v_agency and key = 'default_days_target' limit 1), 22);
  v_hours_target := coalesce(v_custom_hours, (select (value #>> '{}')::numeric from app_settings where agency_id = v_agency and key = 'default_hours_target' limit 1), 100);
  v_diamond_target := coalesce((v_cfg ->> 'diamond_target')::numeric, 80000);

  select * into st from journey_stages where id = journey_stage_for(v_me);

  select count(*) filter (where sa.id is not null and sa.revoked_at is null), count(*)
  into v_unlocked, v_total
  from achievements a
  left join streamer_achievements sa on sa.achievement_id = a.id and sa.streamer_id = v_me
  where a.agency_id = v_agency and a.is_active;

  select coalesce(max(diamonds) filter (where is_current), 0) as diamonds,
         coalesce(max(days) filter (where is_current), 0) as days,
         coalesce(max(hours) filter (where is_current), 0) as hours,
         coalesce(sum(hours), 0) as total_hours
  into v_cur
  from streamer_month_series(v_me);

  select s.diamonds, s.period_key into v_record_value, v_record_period
  from streamer_month_series(v_me) s order by s.diamonds desc limit 1;

  return jsonb_build_object(
    'name', v_name,
    'avatar_url', v_avatar,
    'stage_name', st.name,
    'stage_description', st.description,
    'crest_key', coalesce(st.crest_key, 'prata'),
    'crest_image_url', st.crest_image_url,
    'stage_order', coalesce(st.sort_order, 1),
    'unlocked', v_unlocked,
    'total', v_total,
    'current_diamonds', v_cur.diamonds,
    'current_days', v_cur.days,
    'current_hours', v_cur.hours,
    'days_target', v_days_target,
    'hours_target', v_hours_target,
    'diamond_target', v_diamond_target,
    'total_hours', v_cur.total_hours,
    'record_value', coalesce(v_record_value, 0),
    'record_period', v_record_period,
    'constancy', journey_constancy(v_me),
    'onboarding', journey_onboarding(v_me)
  );
end;
$$;
grant execute on function app_my_journey() to authenticated;

-- constancia tambem disponivel sozinha (Home)
create or replace function app_my_constancy()
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare v_me uuid;
begin
  select id into v_me from profiles where auth_user_id = auth.uid() limit 1;
  if v_me is null then return null; end if;
  return journey_constancy(v_me);
end;
$$;
grant execute on function app_my_constancy() to authenticated;

-- ----------------------------------------------------------------------------
-- 7) Recalcula tudo com o catalogo novo
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

-- ============================================================================
-- Jornada v2: META ADAPTATIVA centralizada + avatar no resumo + responsavel
-- na Jornada MDUCK.
--
-- journey_recommended_milestone(streamer) e a UNICA fonte da meta mostrada no
-- app (nada de ifs no app). Considera:
--   mes atual, media recente (ultimos N meses fechados), melhor resultado da
--   janela, se ja bateu um patamar e esta retomando, e se esta consistentemente
--   acima do grande horizonte. Valores sempre vem da escada de Marcos do Mes.
--
-- Modos (internos, nunca exibidos como classificacao):
--   start     sem historico ainda            -> primeiro degrau + grande horizonte
--   build     construindo (abaixo do 80K)    -> degrau do nivel atual, depois, horizonte
--   comeback  ja bateu um patamar e quer voltar (ate N degraus acima do nivel
--             recente)                      -> "Vamos buscar os 80K novamente"
--   steady    consistentemente >= horizonte -> "Seu marco mensal" + proximo desafio
-- Se o mes atual ja passou da meta, a meta sobe pro proximo degrau ("Mais um passo").
--
-- Textos e parametros em app_settings 'journey_config' (painel > Configuracoes).
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

create or replace function journey_recommended_milestone(p_streamer_id uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_agency uuid;
  v_cfg jsonb;
  v_steps numeric[];
  v_n int;
  v_horizon numeric;
  v_recent int;
  v_lookback int;
  v_tol numeric;
  v_max_comeback int;
  v_cur_key text := to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM');
  v_from text;
  v_recent_from text;
  v_cur numeric := 0;
  v_avg numeric;
  v_recent_best numeric := 0;
  v_window_best numeric := 0;
  v_closed int := 0;
  v_monthly numeric;
  v_monthly_i int;
  v_best_step numeric;
  v_best_i int;
  v_mode text;
  v_target numeric;
  v_comeback numeric;
  v_reco numeric;
  v_after numeric;
  v_label text;
  v_message text;
  v_after_label text;
  v_show_horizon boolean;
  i int;
begin
  select agency_id into v_agency from profiles where id = p_streamer_id;
  select value into v_cfg from app_settings where agency_id = v_agency and key = 'journey_config' limit 1;
  v_cfg := coalesce(v_cfg, '{}'::jsonb);
  v_horizon := coalesce((v_cfg ->> 'horizon_value')::numeric, 80000);
  v_recent := greatest(coalesce((v_cfg ->> 'recent_months')::int, 3), 1);
  v_lookback := greatest(coalesce((v_cfg ->> 'lookback_months')::int, 6), v_recent);
  v_tol := greatest(coalesce((v_cfg ->> 'level_tolerance')::numeric, 1.1), 1);
  v_max_comeback := greatest(coalesce((v_cfg ->> 'comeback_max_steps')::int, 1), 0);

  select array_agg(value order by value) into v_steps from monthly_milestones where agency_id = v_agency and is_active;
  if v_steps is null then v_steps := array[10000, 20000, 40000, 80000, 150000, 250000, 300000, 500000]; end if;
  v_n := array_length(v_steps, 1);

  v_from := to_char((now() at time zone 'America/Sao_Paulo') - make_interval(months => v_lookback), 'YYYY-MM');
  v_recent_from := to_char((now() at time zone 'America/Sao_Paulo') - make_interval(months => v_recent), 'YYYY-MM');

  select coalesce(max(diamonds) filter (where is_current), 0),
         avg(diamonds) filter (where not is_current and period_key >= v_recent_from),
         coalesce(max(diamonds) filter (where not is_current and period_key >= v_recent_from), 0),
         coalesce(max(diamonds) filter (where not is_current and period_key >= v_from), 0),
         count(*) filter (where not is_current and period_key >= v_from)
  into v_cur, v_avg, v_recent_best, v_window_best, v_closed
  from streamer_month_series(p_streamer_id);

  -- nivel recente (media dos ultimos meses fechados) -> degrau do nivel
  v_monthly_i := 0;
  if v_avg is not null then
    for i in 1..v_n loop
      if v_steps[i] <= v_avg * v_tol then v_monthly_i := i; end if;
    end loop;
  end if;
  if v_monthly_i = 0 then v_monthly_i := 1; end if;
  v_monthly := v_steps[v_monthly_i];

  -- maior degrau ja batido na janela
  v_best_i := 0;
  for i in 1..v_n loop
    if v_steps[i] <= v_window_best then v_best_i := i; end if;
  end loop;
  v_best_step := case when v_best_i > 0 then v_steps[v_best_i] end;

  if v_closed = 0 and v_cur < v_steps[1] then
    v_mode := 'start';
    v_target := v_steps[1];
  elsif v_best_i > v_monthly_i
        and v_best_i - v_monthly_i <= v_max_comeback then
    v_mode := 'comeback';
    v_comeback := v_best_step;
    v_target := v_best_step;
  elsif v_avg is not null and v_avg >= v_horizon then
    v_mode := 'steady';
    v_target := v_monthly;
  else
    v_mode := 'build';
    v_target := v_monthly;
  end if;

  -- o mes atual ja passou da meta? sobe um degrau (sem pular varios)
  v_reco := v_target;
  if v_cur >= v_target then
    select min(s) into v_reco from unnest(v_steps) s where s > v_cur;
    if v_reco is null then v_reco := v_steps[v_n]; end if;
  end if;
  select min(s) into v_after from unnest(v_steps) s where s > v_reco;

  v_show_horizon := v_mode in ('start', 'build') and v_reco < v_horizon;

  v_label := case
    when v_cur >= v_target and v_reco > v_target then coalesce(v_cfg ->> 'text_more', 'Mais um passo')
    when v_mode = 'steady' then coalesce(v_cfg ->> 'text_steady', 'Seu marco mensal')
    when v_mode = 'start' then coalesce(v_cfg ->> 'text_start', 'Seu primeiro marco')
    else coalesce(v_cfg ->> 'text_next', 'Seu próximo marco') end;
  v_message := case
    when v_cur >= v_target and v_reco > v_target then coalesce(v_cfg ->> 'msg_more', 'Você já passou da sua meta do mês. Bora para o próximo degrau.')
    when v_mode = 'comeback' then replace(coalesce(v_cfg ->> 'msg_comeback', 'Vamos buscar os {valor} novamente.'), '{valor}', (v_reco / 1000)::int || 'K')
    when v_mode = 'steady' then coalesce(v_cfg ->> 'msg_steady', 'O seu patamar de todo mês. Mantenha o ritmo.')
    when v_mode = 'start' then coalesce(v_cfg ->> 'msg_start', 'Cada live te aproxima do seu primeiro marco.')
    else coalesce(v_cfg ->> 'msg_build', 'Um objetivo do seu tamanho para este mês.') end;
  v_after_label := case when v_mode = 'steady' then coalesce(v_cfg ->> 'text_challenge', 'Próximo desafio')
                        else coalesce(v_cfg ->> 'text_after', 'Depois') end;

  return jsonb_build_object(
    'mode', v_mode,
    'recommended', v_reco,
    'current_target', v_target,
    'comeback_target', v_comeback,
    'stretch_target', v_after,
    'horizon', case when v_show_horizon then v_horizon end,
    'label', v_label,
    'message', v_message,
    'after_label', v_after_label,
    'horizon_label', coalesce(v_cfg ->> 'text_horizon', 'Grande horizonte'),
    'current', v_cur
  );
end;
$$;

-- resumo da Jornada: meta vem da funcao acima; + avatar pro cartao de compartilhar
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
  st journey_stages;
  v_goal jsonb;
  v_unlocked int;
  v_total int;
  v_month_top numeric;
  v_month_count int;
begin
  select p.id, p.agency_id, coalesce(nullif(p.tiktok_username, ''), p.display_name), p.avatar_url
  into v_me, v_agency, v_name, v_avatar
  from profiles p where p.auth_user_id = auth.uid() limit 1;
  if v_me is null then return null; end if;

  perform evaluate_streamer_achievements(v_me);
  perform evaluate_streamer_month_milestones(v_me);

  select * into st from journey_stages where id = journey_stage_for(v_me);
  v_goal := journey_recommended_milestone(v_me);

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
    'avatar_url', v_avatar,
    'stage_name', st.name,
    'stage_description', st.description,
    'crest_key', coalesce(st.crest_key, 'prata'),
    'crest_image_url', st.crest_image_url,
    'stage_order', coalesce(st.sort_order, 1),
    'unlocked', v_unlocked,
    'total', v_total,
    'current_diamonds', coalesce((v_goal ->> 'current')::numeric, 0),
    'goal', v_goal,
    -- compatibilidade com a versao anterior do app
    'goal_label', v_goal ->> 'label',
    'goal_value', (v_goal ->> 'recommended')::numeric,
    'secondary_label', case when v_goal ->> 'horizon' is not null then v_goal ->> 'horizon_label' else v_goal ->> 'after_label' end,
    'secondary_value', coalesce((v_goal ->> 'horizon')::numeric, (v_goal ->> 'stretch_target')::numeric),
    'horizon_value', (v_goal ->> 'horizon')::numeric,
    'month_top_value', v_month_top,
    'month_count', coalesce(v_month_count, 0)
  );
end;
$$;
grant execute on function app_my_journey() to authenticated;

-- Jornada MDUCK: inclui o responsavel (nome de quem registrou)
drop function if exists app_my_inventory();
create or replace function app_my_inventory()
returns table (
  id uuid,
  category text,
  title text,
  description text,
  occurred_at date,
  image_url text,
  amount numeric,
  status text,
  responsible text
)
language sql stable security definer
set search_path = public
as $$
  select
    e.id, e.category, e.title, e.description, e.occurred_at, e.image_url,
    case when e.show_amount then e.amount else null end as amount,
    e.status,
    nullif(trim(m.full_name), '') as responsible
  from streamer_inventory_entries e
  join profiles p on p.id = e.streamer_id
  left join managers m on m.id = e.created_by
  where p.auth_user_id = auth.uid()
    and e.visible_to_streamer
    and e.status <> 'cancelado'
  order by e.occurred_at desc, e.created_at desc;
$$;
grant execute on function app_my_inventory() to authenticated;

-- emblemas proprios dos Primeiros Passos / Dedicacao (so onde ainda esta o padrao)
update achievements set icon_key = 'portal'   where code = 'first_live'      and icon_key = 'live';
update achievements set icon_key = 'steps'    where code = 'days_month_5'    and icon_key = 'calendar';
update achievements set icon_key = 'crystal'  where code = 'days_month_10'   and icon_key = 'calendar';
update achievements set icon_key = 'crystals' where code = 'days_month_15'   and icon_key = 'calendar';
update achievements set icon_key = 'laurel'   where code = 'days_month_22'   and icon_key = 'calendar';
update achievements set icon_key = 'hourglass' where code = 'hours_month_80' and icon_key = 'clock';
update achievements set icon_key = 'flame'    where code = 'hours_month_100' and icon_key = 'clock';

-- parametros novos da meta (mantem o que ja foi configurado)
update app_settings
set value = jsonb_build_object('recent_months', 3, 'level_tolerance', 1.1, 'comeback_max_steps', 1) || value,
    updated_at = now()
where key = 'journey_config';

notify pgrst, 'reload schema';

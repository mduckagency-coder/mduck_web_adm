-- ============================================================================
-- 1. Configuracoes do Aplicativo (CMS leve): Sobre a MDuck, Ajuda/FAQ, suporte,
--    textos da tela de Configuracoes, versao e data da ultima atualizacao.
--    Fica em app_settings 'app_config' (mesma estrutura ja usada no projeto).
-- 2. Reportes do Aplicativo (separado dos bugs do painel: bug_reports):
--    tabela app_reports + bucket privado app_reports (screenshots).
-- 3. Identidade TikTok (Login Kit / OAuth 2.0): identidades, tokens (so o
--    servidor le) e estados do OAuth. O fluxo roda na Edge Function
--    supabase/functions/tiktok-auth (segredos ficam no servidor).
-- 4. Chama da Constancia: textos novos (reacendida / volte ao seu ritmo) e
--    dicas de "falta pouco" pros 22 dias / 100 horas.
-- 5. Jornada: tipos novos "evolucao" e "objetivo".
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Configuracoes do app
-- ----------------------------------------------------------------------------
create or replace function app_config_defaults()
returns jsonb
language sql stable
as $$
  select jsonb_build_object(
    'version_label', '1.0.0 Beta',
    'last_update', to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM-DD'),
    'about_title', 'Sobre a MDuck',
    'about_text', 'A MDuck Agency acompanha streamers do TikTok no dia a dia: estratégia, constância, resultados e reconhecimento. Este aplicativo reúne sua jornada, seus marcos do mês e suas conquistas em um só lugar.',
    'help_text', 'Precisa de ajuda? Veja as perguntas frequentes abaixo ou fale com a equipe da MDuck Agency.',
    'faq', jsonb_build_array(
      jsonb_build_object('q', 'Quando meus números são atualizados?', 'a', 'Os dados de dias, horas e diamantes são atualizados sempre que a equipe importa a planilha oficial do TikTok.'),
      jsonb_build_object('q', 'O que é a meta profissional do mês?', 'a', '22 dias de live, 100 horas ao vivo e 80K diamantes no mês: o ritmo de quem trata a live como profissão.'),
      jsonb_build_object('q', 'Como desbloqueio a arte de um marco?', 'a', 'Quando você alcança um marco de diamantes no mês (10K, 20K, 40K, 80K...), a arte é liberada automaticamente com a sua foto e o seu @, pronta para compartilhar.'),
      jsonb_build_object('q', 'Encontrei um dado errado. O que faço?', 'a', 'Use Configurações > Reportar um problema e escolha "Dados incorretos ou desatualizados".')
    ),
    'support_text', 'Fale com a equipe MDuck Agency pelos canais abaixo.',
    'support_whatsapp', '',
    'support_email', '',
    'settings_title', 'Configurações',
    'report_intro', 'Conte o que aconteceu. Nós já registramos automaticamente sua conta, a data e a versão do app.',
    'report_success', 'Recebemos seu reporte. Obrigado por ajudar a melhorar o app!',
    'app_info_text', 'Aplicativo oficial dos streamers da MDuck Agency.'
  );
$$;

create or replace function app_get_config()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select app_config_defaults() || coalesce((
    select s.value from app_settings s
    join profiles p on p.agency_id = s.agency_id
    where p.auth_user_id = auth.uid() and s.key = 'app_config'
    limit 1
  ), '{}'::jsonb);
$$;
grant execute on function app_get_config() to authenticated;

-- ----------------------------------------------------------------------------
-- 2) Reportes do aplicativo
-- ----------------------------------------------------------------------------
create table if not exists app_reports (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid,
  streamer_id uuid references profiles(id) on delete set null,
  auth_user_id uuid,
  streamer_name text,
  streamer_username text,
  type text not null check (type in ('bug', 'dados', 'imagem_conquista', 'conta', 'sugestao', 'outro')),
  description text not null,
  screenshot_path text,
  app_version text,
  platform text,
  status text not null default 'novo' check (status in ('novo', 'em_analise', 'resolvido', 'ignorado', 'duplicado')),
  admin_note text,
  handled_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_app_reports_agency on app_reports(agency_id, created_at desc);
alter table app_reports enable row level security;

drop policy if exists "app_reports_managers" on app_reports;
create policy "app_reports_managers" on app_reports
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "app_reports_own_select" on app_reports;
create policy "app_reports_own_select" on app_reports
  for select using (auth_user_id = auth.uid());

-- o app envia por aqui: nome, @, conta, data e versao vem do sistema
create or replace function app_submit_report(
  p_type text, p_description text, p_screenshot_path text default null,
  p_app_version text default null, p_platform text default null)
returns uuid
language plpgsql volatile security definer
set search_path = public
as $$
declare
  p record;
  v_id uuid;
begin
  if coalesce(trim(p_description), '') = '' then raise exception 'descreva o problema'; end if;
  select id, agency_id, display_name, tiktok_username into p from profiles where auth_user_id = auth.uid() limit 1;
  insert into app_reports (agency_id, streamer_id, auth_user_id, streamer_name, streamer_username, type, description,
                           screenshot_path, app_version, platform)
  values (p.agency_id, p.id, auth.uid(), p.display_name, p.tiktok_username, p_type, trim(p_description),
          nullif(p_screenshot_path, ''), p_app_version, p_platform)
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function app_submit_report(text, text, text, text, text) to authenticated;

-- screenshots: bucket privado; o streamer grava na propria pasta, gestor le
insert into storage.buckets (id, name, public) values ('app_reports', 'app_reports', false)
on conflict (id) do nothing;

drop policy if exists "app_reports_upload_own" on storage.objects;
create policy "app_reports_upload_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'app_reports' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "app_reports_read_managers" on storage.objects;
create policy "app_reports_read_managers" on storage.objects
  for select to authenticated
  using (bucket_id = 'app_reports' and (exists (select 1 from managers where id = auth.uid()) or (storage.foldername(name))[1] = auth.uid()::text));

-- ----------------------------------------------------------------------------
-- 3) Identidade TikTok
-- ----------------------------------------------------------------------------
create table if not exists tiktok_identities (
  open_id text primary key,
  union_id text,
  profile_id uuid not null unique references profiles(id) on delete cascade,
  auth_user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  scopes text,
  linked_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table tiktok_identities enable row level security;
drop policy if exists "tiktok_identities_managers" on tiktok_identities;
create policy "tiktok_identities_managers" on tiktok_identities
  for select using (exists (select 1 from managers m join profiles p on p.agency_id = m.agency_id where m.id = auth.uid() and p.id = tiktok_identities.profile_id));

-- tokens: sem policy = so a service role (Edge Function) acessa
create table if not exists tiktok_tokens (
  open_id text primary key references tiktok_identities(open_id) on delete cascade,
  access_token text not null,
  refresh_token text,
  expires_at timestamptz,
  refresh_expires_at timestamptz,
  scope text,
  updated_at timestamptz not null default now()
);
alter table tiktok_tokens enable row level security;

create table if not exists tiktok_oauth_states (
  state text primary key,
  mode text not null check (mode in ('login', 'link')),
  user_id uuid,
  created_at timestamptz not null default now()
);
alter table tiktok_oauth_states enable row level security;

-- status da conexao pro app (sem tokens)
create or replace function app_my_tiktok()
returns jsonb
language sql stable security definer
set search_path = public
as $$
  select coalesce((
    select jsonb_build_object('connected', true, 'display_name', t.display_name, 'username', t.username,
                              'avatar_url', t.avatar_url, 'linked_at', t.linked_at)
    from tiktok_identities t join profiles p on p.id = t.profile_id
    where p.auth_user_id = auth.uid()
    limit 1
  ), jsonb_build_object('connected', false));
$$;
grant execute on function app_my_tiktok() to authenticated;

-- fotos de perfil vindas do TikTok (copia estavel; as URLs do TikTok expiram)
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 4) Chama da Constancia: textos + "falta pouco"
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
  v_diamonds numeric := 0;
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
  v_hint text;
  v_intensity numeric;
begin
  select coalesce(days_live, 0), coalesce(hours_live, 0), coalesce(diamonds, 0) into v_days, v_hours, v_diamonds from streamer_stats where streamer_id = p_streamer_id;
  v_days := coalesce(v_days, 0);
  v_hours := coalesce(v_hours, 0);
  v_diamonds := coalesce(v_diamonds, 0);
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
    v_label := 'Chama enfraquecendo';
    v_msg := 'Volte ao seu ritmo: uma live hoje já reacende sua constância.';
    v_intensity := 0.15;
  elsif v_gap <= 3 and v_pdays <= 4 and v_days between 1 and 5 then
    v_state := 'retomando';
    v_label := 'Chama reacendida!';
    v_msg := 'Que bom te ver de volta. Mantenha as lives nos próximos dias.';
    v_intensity := greatest(v_intensity, 0.35);
  elsif v_proj_days >= 18 and v_proj_hours >= 80 then
    v_state := 'forte';
    v_label := 'Chama forte';
    v_msg := 'Você está no ritmo de um mês profissional.';
  elsif v_proj_days > v_pdays * 1.1 or v_proj_hours > v_phours * 1.1 then
    v_state := 'evolucao';
    v_label := 'Chama evoluindo';
    v_msg := 'Sua frequência está subindo em relação ao mês passado.';
  elsif v_proj_days < v_pdays * 0.8 and v_proj_days < 14 then
    v_state := 'alerta';
    v_label := 'Chama enfraquecendo';
    v_msg := 'Volte ao seu ritmo: programe suas próximas lives da semana.';
  else
    v_state := 'estavel';
    v_label := 'Ritmo estável';
    v_msg := 'Você está mantendo o ritmo. Rumo aos 22 dias e 100 horas.';
  end if;

  -- "estou chegando perto": dicas concretas sem reduzir a meta
  v_hint := case
    when v_days between 18 and 21 then 'Faltam ' || (22 - v_days)::int || ' dia(s) de live para os 22.'
    when v_hours between 80 and 99.99 then 'Faltam ' || ceil(100 - v_hours)::int || 'h para as 100 horas.'
    when v_diamonds between 60000 and 79999 then 'Você está perto dos 80K: faltam ' || round((80000 - v_diamonds) / 1000)::int || 'K.'
    else null end;
  if v_hint is not null and v_state <> 'alerta' then v_msg := v_msg || ' ' || v_hint; end if;

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
-- 5) Jornada: tipos evolucao e objetivo
-- ----------------------------------------------------------------------------
alter table streamer_inventory_entries drop constraint if exists streamer_inventory_entries_category_check;
alter table streamer_inventory_entries add constraint streamer_inventory_entries_category_check
  check (category in ('presente', 'treinamento', 'conquista', 'recompensa', 'campanha', 'evento', 'suporte', 'pix',
                      'reconhecimento', 'evolucao', 'objetivo', 'outros'));

notify pgrst, 'reload schema';

-- ============================================================================
-- Modulo Calendario - Solicitacoes (etapa "futura" citada em 0001_calendario.sql)
-- Aditivo: seguro rodar mesmo com as etapas 1 e 2 ja aplicadas.
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

-- 1) calendar_requests: campos especificos de Batalha Oficial e Evento -----

alter table calendar_requests add column if not exists battle_rounds smallint;
alter table calendar_requests add column if not exists battle_diamonds_estimate integer;
alter table calendar_requests add column if not exists battle_opponent_type text;
alter table calendar_requests add column if not exists needs_banner boolean not null default false;

-- request_type agora e fechado em batalha_oficial/evento (era texto livre)
alter table calendar_requests drop constraint if exists calendar_requests_request_type_check;
alter table calendar_requests add constraint calendar_requests_request_type_check
  check (request_type in ('batalha_oficial', 'evento'));

alter table calendar_requests drop constraint if exists calendar_requests_battle_rounds_check;
alter table calendar_requests add constraint calendar_requests_battle_rounds_check
  check (battle_rounds is null or battle_rounds in (1, 3));

alter table calendar_requests drop constraint if exists calendar_requests_battle_opponent_type_check;
alter table calendar_requests add constraint calendar_requests_battle_opponent_type_check
  check (battle_opponent_type is null or battle_opponent_type in ('agencia', 'externo', 'tanto_faz'));

-- Batalha oficial nao exige titulo digitado pelo streamer (a UI monta um
-- titulo de exibicao); Evento continua exigindo titulo na validacao da tela.
alter table calendar_requests alter column title drop not null;

comment on column calendar_requests.request_type is 'batalha_oficial | evento';
comment on column calendar_requests.battle_rounds is 'Somente para batalha_oficial: 1 ou 3';
comment on column calendar_requests.battle_diamonds_estimate is 'Somente para batalha_oficial: diamantes aproximados';
comment on column calendar_requests.battle_opponent_type is 'Somente para batalha_oficial: agencia | externo | tanto_faz';
comment on column calendar_requests.needs_banner is 'Streamer pediu banner de divulgacao (batalha ou evento)';

-- 2) calendar_request_prompts: agencia pede para o streamer preencher uma
--    solicitacao (o streamer ainda nao preencheu nada; e so um convite) ----

create table if not exists calendar_request_prompts (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id),
  request_type text not null check (request_type in ('batalha_oficial', 'evento')),
  message text not null,
  suggested_date_start date,
  suggested_date_end date,
  requested_by_manager_id uuid not null references managers(id),
  status text not null default 'pendente' check (status in ('pendente', 'atendido', 'ignorado')),
  fulfilled_request_id uuid references calendar_requests(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_calendar_request_prompts_agency_status on calendar_request_prompts(agency_id, status);
create index if not exists idx_calendar_request_prompts_streamer on calendar_request_prompts(streamer_id, status);

-- 3) streamer_notifications: alertas para o streamer (aprovado/reprovado
--    com motivo/pedido da agencia), mesmo padrao de manager_notifications --

create table if not exists streamer_notifications (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id),
  type text not null check (type in ('solicitacao_aprovada', 'solicitacao_rejeitada', 'pedido_agencia', 'geral')),
  subject text not null,
  message text not null,
  related_request_id uuid references calendar_requests(id),
  related_prompt_id uuid references calendar_request_prompts(id),
  created_by uuid references managers(id),
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_streamer_notifications_streamer on streamer_notifications(streamer_id, read_at);

-- ============================================================================
-- RLS
-- ============================================================================
alter table calendar_request_prompts enable row level security;
alter table streamer_notifications enable row level security;

-- calendar_requests ja tem RLS da agencia (0001_calendario.sql); adiciona
-- leitura/insercao para o proprio streamer (usado pelo app do streamer,
-- ainda nao implementado nesta etapa, mas a policy ja fica pronta).
drop policy if exists "calendar_requests_streamer_select" on calendar_requests;
create policy "calendar_requests_streamer_select" on calendar_requests
  for select using (
    requested_by_streamer_id in (select id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "calendar_requests_streamer_insert" on calendar_requests;
create policy "calendar_requests_streamer_insert" on calendar_requests
  for insert with check (
    requested_by_streamer_id in (select id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "calendar_request_prompts_agency" on calendar_request_prompts;
create policy "calendar_request_prompts_agency" on calendar_request_prompts
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "calendar_request_prompts_streamer_select" on calendar_request_prompts;
create policy "calendar_request_prompts_streamer_select" on calendar_request_prompts
  for select using (
    streamer_id in (select id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "streamer_notifications_agency" on streamer_notifications;
create policy "streamer_notifications_agency" on streamer_notifications
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "streamer_notifications_streamer_select" on streamer_notifications;
create policy "streamer_notifications_streamer_select" on streamer_notifications
  for select using (
    streamer_id in (select id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "streamer_notifications_streamer_mark_read" on streamer_notifications;
create policy "streamer_notifications_streamer_mark_read" on streamer_notifications
  for update using (
    streamer_id in (select id from profiles where auth_user_id = auth.uid())
  )
  with check (
    streamer_id in (select id from profiles where auth_user_id = auth.uid())
  );

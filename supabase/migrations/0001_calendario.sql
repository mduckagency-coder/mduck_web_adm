-- ============================================================================
-- Modulo Calendario - Etapa 1
-- Rode este script manualmente no SQL Editor do Supabase (projeto do mduck_web_adm).
-- Nao ha CLI/credenciais do Supabase disponiveis no ambiente que gerou este arquivo,
-- entao ele NAO foi aplicado automaticamente.
--
-- ATENCAO: a coluna agency_id NAO tem FK explicita para a tabela de agencias,
-- pois o nome exato dessa tabela nao foi confirmado. Se o projeto tiver uma
-- tabela "agencies" (ou equivalente), adicione manualmente:
--   ALTER TABLE calendar_events ADD CONSTRAINT calendar_events_agency_fk
--     FOREIGN KEY (agency_id) REFERENCES agencies(id);
-- (e o mesmo para as demais tabelas abaixo que tem agency_id)
-- ============================================================================

-- 1) Categorias de evento (agency-scoped, mesmo padrao de lead_kanban_stages)
create table if not exists event_categories (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  key text not null,
  name text not null,
  color text not null default '#7A0BD4',
  icon_key text,
  order_index int not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_event_categories_agency on event_categories(agency_id);

-- 2) Eventos (fonte unica de dados, usada pelas 3 paginas do modulo e futuramente pelo app)
create table if not exists calendar_events (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  category_id uuid references event_categories(id),
  title text not null,
  description text,
  event_date date not null,
  start_time time,
  end_time time,
  all_day boolean not null default false,
  location text,
  meeting_link text,
  notes text,
  priority text not null default 'normal' check (priority in ('baixa', 'normal', 'alta', 'urgente')),
  status text not null default 'agendado' check (status in ('agendado', 'confirmado', 'em_andamento', 'finalizado', 'cancelado')),
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_calendar_events_agency_date on calendar_events(agency_id, event_date);
create index if not exists idx_calendar_events_category on calendar_events(category_id);

-- 3) Participantes do evento (streamer e/ou gestor responsavel, com funcao)
create table if not exists calendar_event_participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references calendar_events(id) on delete cascade,
  participant_type text not null check (participant_type in ('streamer', 'gestor')),
  streamer_id uuid references profiles(id),
  manager_id uuid references managers(id),
  role_label text,
  created_at timestamptz not null default now(),
  constraint chk_participant_ref check (
    (participant_type = 'streamer' and streamer_id is not null and manager_id is null)
    or
    (participant_type = 'gestor' and manager_id is not null and streamer_id is null)
  )
);
create index if not exists idx_calendar_participants_event on calendar_event_participants(event_id);
create index if not exists idx_calendar_participants_streamer on calendar_event_participants(streamer_id);
create index if not exists idx_calendar_participants_manager on calendar_event_participants(manager_id);

-- 4) Anexos do evento (tabela criada agora; UI de upload fica para etapa futura)
create table if not exists calendar_event_attachments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references calendar_events(id) on delete cascade,
  file_name text not null,
  file_url text not null,
  uploaded_by uuid references managers(id),
  uploaded_at timestamptz not null default now()
);
create index if not exists idx_calendar_attachments_event on calendar_event_attachments(event_id);

-- 5) Solicitacoes (Solicitacoes - tabela criada agora; pagina/fluxo de aprovacao ficam para etapa futura)
create table if not exists calendar_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  request_type text not null,
  title text not null,
  description text,
  requested_by_streamer_id uuid references profiles(id),
  requested_by_manager_id uuid references managers(id),
  proposed_date date,
  proposed_start_time time,
  proposed_end_time time,
  related_event_id uuid references calendar_events(id),
  status text not null default 'aguardando_analise' check (status in ('aguardando_analise', 'aprovada', 'rejeitada', 'cancelada')),
  review_notes text,
  reviewed_by uuid references managers(id),
  reviewed_at timestamptz,
  created_event_id uuid references calendar_events(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_calendar_requests_agency_status on calendar_requests(agency_id, status);

-- ============================================================================
-- RLS (policy-modelo baseada em agency_id do manager logado - REVISE contra as
-- policies ja existentes de tabelas como lead_kanban_stages antes de confiar
-- nisso em producao, pois nao tive acesso ao schema/policies atuais do projeto)
-- ============================================================================
alter table event_categories enable row level security;
alter table calendar_events enable row level security;
alter table calendar_event_participants enable row level security;
alter table calendar_event_attachments enable row level security;
alter table calendar_requests enable row level security;

drop policy if exists "calendario_event_categories_agency" on event_categories;
create policy "calendario_event_categories_agency" on event_categories
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "calendario_calendar_events_agency" on calendar_events;
create policy "calendario_calendar_events_agency" on calendar_events
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "calendario_calendar_event_participants_agency" on calendar_event_participants;
create policy "calendario_calendar_event_participants_agency" on calendar_event_participants
  for all using (
    exists (
      select 1 from calendar_events e
      where e.id = calendar_event_participants.event_id
      and e.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from calendar_events e
      where e.id = calendar_event_participants.event_id
      and e.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

drop policy if exists "calendario_calendar_event_attachments_agency" on calendar_event_attachments;
create policy "calendario_calendar_event_attachments_agency" on calendar_event_attachments
  for all using (
    exists (
      select 1 from calendar_events e
      where e.id = calendar_event_attachments.event_id
      and e.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from calendar_events e
      where e.id = calendar_event_attachments.event_id
      and e.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

drop policy if exists "calendario_calendar_requests_agency" on calendar_requests;
create policy "calendario_calendar_requests_agency" on calendar_requests
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

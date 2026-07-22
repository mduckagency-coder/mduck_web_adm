-- ============================================================================
-- Modulo Eventos
-- Rode manualmente no SQL Editor do Supabase (mesmo padrao das migrations
-- anteriores). Modulo independente: nao altera calendar_events (Calendario)
-- nem agency_campaigns/campaign_rewards (Campanhas).
--
-- A entidade principal se chama "agency_events" (nao "events") porque um
-- projeto pode ja ter uma tabela publica chamada "events" vinda de outro
-- lugar (foi o caso aqui - "create table if not exists events" ficou sem
-- efeito contra uma tabela existente com schema diferente, e o create index
-- seguinte quebrou por falta da coluna start_date).
-- ============================================================================

-- 1) Tipos de evento (agency-scoped, editavel no futuro - mesmo padrao de
-- lead_categories).
create table if not exists event_types (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  name text not null,
  color text not null default '#7A0BD4',
  order_index int not null default 999,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (agency_id, name)
);
create index if not exists idx_event_types_agency on event_types(agency_id);

-- 2) Evento
create table if not exists agency_events (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  type_id uuid references event_types(id),
  title text not null,
  description text,
  banner_url text,
  status text not null default 'planejado' check (status in ('planejado', 'em_andamento', 'finalizado', 'cancelado')),
  start_date date not null,
  end_date date not null,
  responsible_manager_id uuid references managers(id),
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_agency_events_agency on agency_events(agency_id, start_date);

-- 3) Participantes (streamer ou gestor, com papel - mesmo padrao de
-- calendar_event_participants, tabela propria)
create table if not exists event_participants (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  participant_type text not null check (participant_type in ('streamer', 'gestor')),
  streamer_id uuid references profiles(id),
  manager_id uuid references managers(id),
  role_label text,
  created_at timestamptz not null default now(),
  constraint chk_event_participant_ref check (
    (participant_type = 'streamer' and streamer_id is not null and manager_id is null)
    or
    (participant_type = 'gestor' and manager_id is not null and streamer_id is null)
  )
);
create index if not exists idx_event_participants_event on event_participants(event_id);

-- 4) Cronograma
create table if not exists event_schedule (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  activity_date date not null,
  activity_time time,
  description text not null,
  responsible_manager_id uuid references managers(id),
  status text not null default 'pendente' check (status in ('pendente', 'em_andamento', 'concluido', 'cancelado')),
  notes text,
  order_index int not null default 999,
  created_by uuid references managers(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_event_schedule_event on event_schedule(event_id, activity_date);

-- 5) Tarefas
create table if not exists event_tasks (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  title text not null,
  responsible_manager_id uuid references managers(id),
  due_date date,
  status text not null default 'pendente' check (status in ('pendente', 'em_andamento', 'concluido')),
  notes text,
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists idx_event_tasks_event on event_tasks(event_id);

-- 6) Checklist de cada tarefa
create table if not exists event_task_checklist_items (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references event_tasks(id) on delete cascade,
  label text not null,
  done boolean not null default false,
  done_at timestamptz,
  order_index int not null default 999
);
create index if not exists idx_event_task_checklist_task on event_task_checklist_items(task_id);

-- 7) Premiacoes
create table if not exists event_awards (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  name text not null,
  quantity int not null default 1,
  value numeric,
  supplier text,
  status text not null default 'pendente' check (status in ('pendente', 'comprado', 'entregue')),
  delivered_at timestamptz,
  notes text,
  created_by uuid references managers(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_event_awards_event on event_awards(event_id);

-- 8) Orcamento (um por evento)
create table if not exists event_budget (
  event_id uuid primary key references agency_events(id) on delete cascade,
  budget_amount numeric not null default 0,
  updated_at timestamptz not null default now()
);

-- 9) Lancamentos financeiros
create table if not exists event_financial_entries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  entry_type text not null check (entry_type in ('despesa', 'patrocinio', 'compra')),
  description text not null,
  amount numeric not null,
  status text not null default 'pendente' check (status in ('pendente', 'pago', 'recebido')),
  entry_date date not null default current_date,
  created_by uuid references managers(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_event_financial_entries_event on event_financial_entries(event_id);

-- 10) Arquivos
create table if not exists event_attachments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  file_name text not null,
  file_url text not null,
  uploaded_by uuid references managers(id),
  uploaded_at timestamptz not null default now()
);
create index if not exists idx_event_attachments_event on event_attachments(event_id);

-- 11) Historico automatico (a propria aba Historico ja e a timeline)
create table if not exists event_history (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references agency_events(id) on delete cascade,
  action text not null,
  detail text,
  performed_by uuid references managers(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_event_history_event on event_history(event_id);

-- ============================================================================
-- Storage buckets
-- ============================================================================
insert into storage.buckets (id, name, public)
values ('event_banners', 'event_banners', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('event_attachments', 'event_attachments', true)
on conflict (id) do nothing;

-- ============================================================================
-- RLS (mesmo padrao agency-scoped das migrations anteriores)
-- ============================================================================
alter table event_types enable row level security;
drop policy if exists "event_types_agency" on event_types;
create policy "event_types_agency" on event_types
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

alter table agency_events enable row level security;
drop policy if exists "agency_events_agency" on agency_events;
create policy "agency_events_agency" on agency_events
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

alter table event_participants enable row level security;
drop policy if exists "event_participants_agency" on event_participants;
create policy "event_participants_agency" on event_participants
  for all using (exists (select 1 from agency_events e where e.id = event_participants.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_participants.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

alter table event_schedule enable row level security;
drop policy if exists "event_schedule_agency" on event_schedule;
create policy "event_schedule_agency" on event_schedule
  for all using (exists (select 1 from agency_events e where e.id = event_schedule.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_schedule.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

alter table event_tasks enable row level security;
drop policy if exists "event_tasks_agency" on event_tasks;
create policy "event_tasks_agency" on event_tasks
  for all using (exists (select 1 from agency_events e where e.id = event_tasks.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_tasks.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

alter table event_task_checklist_items enable row level security;
drop policy if exists "event_task_checklist_items_agency" on event_task_checklist_items;
create policy "event_task_checklist_items_agency" on event_task_checklist_items
  for all using (
    exists (
      select 1 from event_tasks t join agency_events e on e.id = t.event_id
      where t.id = event_task_checklist_items.task_id and e.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from event_tasks t join agency_events e on e.id = t.event_id
      where t.id = event_task_checklist_items.task_id and e.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

alter table event_awards enable row level security;
drop policy if exists "event_awards_agency" on event_awards;
create policy "event_awards_agency" on event_awards
  for all using (exists (select 1 from agency_events e where e.id = event_awards.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_awards.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

alter table event_budget enable row level security;
drop policy if exists "event_budget_agency" on event_budget;
create policy "event_budget_agency" on event_budget
  for all using (exists (select 1 from agency_events e where e.id = event_budget.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_budget.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

alter table event_financial_entries enable row level security;
drop policy if exists "event_financial_entries_agency" on event_financial_entries;
create policy "event_financial_entries_agency" on event_financial_entries
  for all using (exists (select 1 from agency_events e where e.id = event_financial_entries.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_financial_entries.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

alter table event_attachments enable row level security;
drop policy if exists "event_attachments_agency" on event_attachments;
create policy "event_attachments_agency" on event_attachments
  for all using (exists (select 1 from agency_events e where e.id = event_attachments.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_attachments.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

alter table event_history enable row level security;
drop policy if exists "event_history_agency" on event_history;
create policy "event_history_agency" on event_history
  for all using (exists (select 1 from agency_events e where e.id = event_history.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())))
  with check (exists (select 1 from agency_events e where e.id = event_history.event_id and e.agency_id = (select agency_id from managers where id = auth.uid())));

-- ============================================================================
-- Seed dos tipos de evento padrao (idempotente por agencia)
-- ============================================================================
do $$
declare
  ag record;
  type_names text[] := array['Competicao', 'Campanha', 'Evento Interno', 'Data Comemorativa', 'Treinamento', 'Convencao', 'Projeto Especial'];
  i int;
begin
  for ag in select distinct agency_id from managers where agency_id is not null loop
    for i in 1 .. array_length(type_names, 1) loop
      insert into event_types (agency_id, name, order_index)
      values (ag.agency_id, type_names[i], i)
      on conflict (agency_id, name) do nothing;
    end loop;
  end loop;
end $$;

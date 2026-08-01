-- ============================================================================
-- Base de dados pro CRM unificado do modulo Gestao: campo global de
-- potencial (independente da estrela do Onboarding e da tag de Programas)
-- e uma tabela real de tarefas por streamer ("proxima acao" com data de
-- verdade, ao inves de so texto calculado na hora).
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table profiles
  add column if not exists potential_level text
  check (potential_level in ('baixo', 'medio', 'alto'));

create table if not exists streamer_tasks (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  streamer_id uuid not null references profiles(id) on delete cascade,
  manager_id uuid not null references managers(id),
  title text not null,
  due_at timestamptz,
  completed_at timestamptz,
  created_by uuid not null references managers(id),
  created_at timestamptz not null default now()
);

create index if not exists streamer_tasks_streamer_idx on streamer_tasks (streamer_id);
create index if not exists streamer_tasks_manager_idx on streamer_tasks (manager_id);
create index if not exists streamer_tasks_agency_due_idx on streamer_tasks (agency_id, due_at);

alter table streamer_tasks enable row level security;

create policy "streamer_tasks_agency_access" on streamer_tasks
  for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- ============================================================================
-- Material Acompanhamento: em vez de so criar material, um gestor pode
-- solicitar material a outro colega (descreve o que precisa + prazo). Quem
-- recebe fica com o pedido pendente ate criar o material; ao criar, quem
-- pediu e avisado que foi feito.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

create table if not exists training_material_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  requested_by uuid not null references managers(id),
  assigned_to uuid not null references managers(id),
  stage text not null,
  onboarding_stage_key text,
  niche text check (niche is null or niche in ('gamer', 'batalha', 'musico')),
  description text not null,
  due_date date,
  status text not null default 'pendente' check (status in ('pendente', 'concluido')),
  created_material_id uuid references training_materials(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create index if not exists idx_training_material_requests_assigned on training_material_requests(assigned_to, status);
create index if not exists idx_training_material_requests_requester on training_material_requests(requested_by, status);

alter table training_material_requests enable row level security;
drop policy if exists "training_material_requests_agency" on training_material_requests;
create policy "training_material_requests_agency" on training_material_requests
  for all
  using (agency_id = my_manager_agency_id())
  with check (agency_id = my_manager_agency_id());

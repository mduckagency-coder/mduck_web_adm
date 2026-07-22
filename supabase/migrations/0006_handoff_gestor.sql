-- ============================================================================
-- Handoff Recrutador -> Gestor (Fase 1)
-- Rode manualmente no SQL Editor do Supabase (mesmo padrao das migrations
-- anteriores). Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

-- Formulario da "Transferencia para o Gestor", preenchido uma unica vez por
-- lead, no momento em que o recrutador marca "Convite enviado".
create table if not exists lead_recruitment_handoff (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid not null unique references leads(id) on delete cascade,
  manager_id uuid not null references managers(id),
  niche text,
  category text,
  available_days text,
  available_hours text,
  previous_experience text,
  objectives text,
  attention_points text,
  recruitment_summary text,
  notes text,
  performed_by uuid not null references managers(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_lead_recruitment_handoff_manager on lead_recruitment_handoff(manager_id);

alter table lead_recruitment_handoff enable row level security;
drop policy if exists "lead_recruitment_handoff_agency" on lead_recruitment_handoff;
create policy "lead_recruitment_handoff_agency" on lead_recruitment_handoff
  for all using (
    exists (
      select 1 from leads l
      where l.id = lead_recruitment_handoff.lead_id
      and l.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from leads l
      where l.id = lead_recruitment_handoff.lead_id
      and l.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

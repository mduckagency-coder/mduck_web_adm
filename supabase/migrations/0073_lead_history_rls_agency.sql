-- ============================================================================
-- Mesmo bug da 0018 (manager_assignment_history) e da 0065 (leads e
-- lead_onboarding_gestores): "new row violates row-level security policy
-- for table lead_history" (42501) ao cadastrar um lead em nome de outro
-- gestor/recrutador (LeadFormDialog, cadastro "on behalf") -- quem grava o
-- historico (performed_by = quem esta logado) nao e o recruiter_id do lead,
-- e a policy existente em lead_history (anterior a esta pasta de
-- migrations, criada fora do repo) parece exigir que sejam a mesma pessoa.
--
-- Correcao no mesmo padrao das demais: policy adicional, agency-scoped via
-- leads.agency_id = my_manager_agency_id(). Aditiva -- policies permissivas
-- do Postgres se somam com OR, nunca remove a policy existente. Rode
-- manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table lead_history enable row level security;

drop policy if exists "lead_history_agency_collab" on lead_history;
create policy "lead_history_agency_collab" on lead_history
  for all
  using (
    exists (
      select 1 from leads l
      where l.id = lead_history.lead_id
      and l.agency_id = my_manager_agency_id()
    )
  )
  with check (
    exists (
      select 1 from leads l
      where l.id = lead_history.lead_id
      and l.agency_id = my_manager_agency_id()
    )
  );

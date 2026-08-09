-- ============================================================================
-- Mesmo bug da 0073 (lead_history), agora em lead_onboarding_checklist:
-- "new row violates row-level security policy for table
-- "lead_onboarding_checklist"" (42501) ao abrir Streamers Agenciados pra um
-- lead que o usuario cadastrou em nome de outro recrutador (RecruiterOnboardingCentralPage._load
-- cria o checklist com insert automatico na primeira vez que o card e aberto/listado,
-- e quem chama o insert nem sempre e o recruiter_id do lead).
--
-- lead_onboarding_checklist e anterior a esta pasta de migrations, entao nao
-- sabemos ao certo a policy que ja existe. Correcao no mesmo padrao das
-- demais: policy adicional, agency-scoped via leads.agency_id =
-- my_manager_agency_id(). Aditiva -- nao remove nenhuma policy existente.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table lead_onboarding_checklist enable row level security;

drop policy if exists "lead_onboarding_checklist_agency_collab" on lead_onboarding_checklist;
create policy "lead_onboarding_checklist_agency_collab" on lead_onboarding_checklist
  for all
  using (
    exists (
      select 1 from leads l
      where l.id = lead_onboarding_checklist.lead_id
      and l.agency_id = my_manager_agency_id()
    )
  )
  with check (
    exists (
      select 1 from leads l
      where l.id = lead_onboarding_checklist.lead_id
      and l.agency_id = my_manager_agency_id()
    )
  );

-- ============================================================================
-- "Card feito por outra pessoa": gestor tenta vincular o streamer oficial ou
-- adicionar outro gestor num card de onboarding que nao foi ele quem criou,
-- a tela mostra como se tivesse vinculado mas nao persiste. Sintoma classico
-- de UPDATE bloqueado por RLS -- Supabase nao lanca erro quando um UPDATE
-- nao acha nenhuma linha visivel pra alterar, so nao faz nada, entao a UI
-- segue como se tivesse dado certo.
--
-- leads e lead_onboarding_gestores sao anteriores a esta pasta de
-- migrations, entao nao sabemos ao certo a policy que ja existe -- se for
-- restrita a quem criou o lead (comum em CRM, faz sentido pro Recrutador),
-- ela acaba bloqueando qualquer Gestor que nao seja o dono original do
-- lead/card. Esta migration e aditiva: soma uma policy ampla por agencia,
-- sem remover nenhuma policy existente (policies permissivas do Postgres se
-- somam com OR, nunca com AND -- isso so aumenta acesso, nunca tira).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table leads enable row level security;
drop policy if exists "leads_agency_collab" on leads;
create policy "leads_agency_collab" on leads
  for all
  using (agency_id = my_manager_agency_id())
  with check (agency_id = my_manager_agency_id());

alter table lead_onboarding_gestores enable row level security;
drop policy if exists "lead_onboarding_gestores_agency_collab" on lead_onboarding_gestores;
create policy "lead_onboarding_gestores_agency_collab" on lead_onboarding_gestores
  for all
  using (
    exists (
      select 1 from leads l
      where l.id = lead_onboarding_gestores.lead_id
      and l.agency_id = my_manager_agency_id()
    )
  )
  with check (
    exists (
      select 1 from leads l
      where l.id = lead_onboarding_gestores.lead_id
      and l.agency_id = my_manager_agency_id()
    )
  );

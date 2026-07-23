-- ============================================================================
-- Onboarding 0-15 Dias: backfill dos cards que ficaram faltando por causa de
-- um bug no fluxo "Transferencia para o Gestor" e no seletor de gestor --
-- os dois so chamavam propagateManagerToProfile (que atualiza um card ja
-- existente), mas nunca chamavam a criacao do card em si. Corrigido em
-- lead_handoff_dialog.dart e recruiter_onboarding_central_page.dart; esta
-- migration cria os cards que ficaram faltando para leads ja marcados como
-- "agenciado" com gestor ja definido. Rode manualmente no SQL Editor do
-- Supabase, depois da 0012. Aditivo/idempotente: nao duplica card se ja
-- existir (mesma unicidade usada pelo app).
-- ============================================================================

-- 0) Garante a coluna "dia_0" em qualquer agencia que porventura ainda nao
-- tenha rodado a 0008 (mesmo seed, idempotente).
do $$
declare
  ag record;
begin
  for ag in select distinct agency_id from managers where agency_id is not null loop
    insert into streamer_phase_stages (agency_id, phase_key, stage_key, name, order_index, color)
    values (ag.agency_id, 'onboarding_0_15', 'dia_0', '0 - Proximos Agenciados', 0, '#F2994A')
    on conflict (agency_id, phase_key, stage_key) do nothing;
  end loop;
end $$;

-- 1) Leads ja vinculados ao streamer oficial (profiles), com gestor
-- definido (lead_onboarding_gestores ou profiles.assigned_manager_id), sem
-- card ainda no Onboarding 0-15.
insert into streamer_phase_progress (streamer_id, phase_key, stage_key, manager_id, agency_id, created_by)
select
  l.converted_streamer_id,
  'onboarding_0_15',
  'dia_0',
  coalesce(p.assigned_manager_id, (select g.manager_id from lead_onboarding_gestores g where g.lead_id = l.id limit 1)),
  l.agency_id,
  l.recruiter_id
from leads l
join profiles p on p.id = l.converted_streamer_id
where l.status = 'agenciado'
  and (p.assigned_manager_id is not null or exists (select 1 from lead_onboarding_gestores g where g.lead_id = l.id))
  and not exists (
    select 1 from streamer_phase_progress spp
    where spp.streamer_id = l.converted_streamer_id and spp.phase_key = 'onboarding_0_15'
  )
on conflict (streamer_id, phase_key) do nothing;

-- 2) Leads ainda nao vinculados ao streamer oficial, mas ja "agenciados" e
-- com gestor definido -- card pre-vinculo (mesmo padrao usado pelo app em
-- createOnboardingLeadCardIfNeeded).
insert into streamer_phase_progress (lead_id, phase_key, stage_key, manager_id, agency_id, created_by)
select
  l.id,
  'onboarding_0_15',
  'dia_0',
  (select g.manager_id from lead_onboarding_gestores g where g.lead_id = l.id limit 1),
  l.agency_id,
  l.recruiter_id
from leads l
where l.status = 'agenciado'
  and l.converted_streamer_id is null
  and exists (select 1 from lead_onboarding_gestores g where g.lead_id = l.id)
  and not exists (
    select 1 from streamer_phase_progress spp
    where spp.lead_id = l.id and spp.phase_key = 'onboarding_0_15' and spp.streamer_id is null
  )
on conflict (lead_id, phase_key) where streamer_id is null do nothing;

-- 3) Vincula todos os gestores (lead_onboarding_gestores, N:N) aos cards
-- do Onboarding 0-15 -- cobre tanto os cards criados acima quanto cards
-- antigos que porventura tenham ficado sem o vinculo N:N.
insert into streamer_phase_progress_managers (progress_id, manager_id)
select spp.id, g.manager_id
from streamer_phase_progress spp
join leads l on (l.id = spp.lead_id or l.converted_streamer_id = spp.streamer_id)
join lead_onboarding_gestores g on g.lead_id = l.id
where spp.phase_key = 'onboarding_0_15'
on conflict (progress_id, manager_id) do nothing;

-- Cobre tambem o caso do streamer ja vinculado cujo gestor foi definido so
-- via profiles.assigned_manager_id (sem passar por lead_onboarding_gestores).
insert into streamer_phase_progress_managers (progress_id, manager_id)
select spp.id, p.assigned_manager_id
from streamer_phase_progress spp
join profiles p on p.id = spp.streamer_id
where spp.phase_key = 'onboarding_0_15' and p.assigned_manager_id is not null
on conflict (progress_id, manager_id) do nothing;

-- 4) Historico, para os cards recem criados por este backfill constarem
-- na Timeline como os demais (so entra se ainda nao existir nenhum
-- historico para esse streamer/lead nesta fase).
insert into streamer_phase_history (streamer_id, lead_id, phase_key, action, detail, performed_by)
select
  spp.streamer_id,
  spp.lead_id,
  spp.phase_key,
  case when spp.streamer_id is not null then 'entrada_onboarding' else 'entrada_onboarding_lead' end,
  'Backfill: card recuperado apos correcao do fluxo de transferencia para o gestor',
  spp.created_by
from streamer_phase_progress spp
where spp.phase_key = 'onboarding_0_15'
  and not exists (
    select 1 from streamer_phase_history h
    where h.phase_key = spp.phase_key
      and h.streamer_id is not distinct from spp.streamer_id
      and h.lead_id is not distinct from spp.lead_id
  );

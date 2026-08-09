-- ============================================================================
-- Mesmo bug de "0065_leads_colaboracao_agencia.sql", agora no onboarding do
-- streamer ja agenciado: um gestor cria/mexe no card, e quando OUTRO gestor
-- da mesma agencia tenta marcar um check, fazer anotacao ou editar algo, a
-- acao nao persiste (RLS bloqueando silenciosamente).
--
-- streamer_contact_logs (usada pra anotacao no painel do streamer, ver
-- lib/features/gestor/streamer_side_panel.dart:261) e anterior a esta pasta
-- de migrations, criada direto no Supabase -- nao sabemos a policy original,
-- entao somamos uma policy ampla por agencia (aditivo, nunca remove acesso).
--
-- onboarding_material_check_progress (0020_onboarding_material_check.sql) ja
-- tinha uma policy por agencia, mas dependia de existir uma linha em
-- streamer_phase_progress COM manager_id preenchido pra aquele streamer+fase
-- -- se o card fosse criado sem gestor vinculado (manager_id null), o join
-- falhava pra todo mundo, bloqueando o check de material. Troca pra checar a
-- agencia direto via profiles, igual o padrao ja corrigido em
-- streamer_phase_progress/streamer_phase_checklist_progress (0010).
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table streamer_contact_logs enable row level security;
drop policy if exists "streamer_contact_logs_agency_collab" on streamer_contact_logs;
create policy "streamer_contact_logs_agency_collab" on streamer_contact_logs
  for all
  using (
    exists (
      select 1 from profiles p
      where p.id = streamer_contact_logs.streamer_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from profiles p
      where p.id = streamer_contact_logs.streamer_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

drop policy if exists "onboarding_material_check_progress_agency" on onboarding_material_check_progress;
create policy "onboarding_material_check_progress_agency" on onboarding_material_check_progress
  for all
  using (
    exists (
      select 1 from profiles p
      where p.id = onboarding_material_check_progress.streamer_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from profiles p
      where p.id = onboarding_material_check_progress.streamer_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

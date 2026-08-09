-- ============================================================================
-- A policy de "0071_onboarding_colaboracao_agencia.sql" (via join com
-- profiles) continua bloqueando gestor B num card que nao foi ele quem
-- criou, mesmo com o texto da policy correto (confirmado via pg_policies).
-- Como profiles ja usa is_manager() pra liberar QUALQUER gestor amplamente
-- ("gestor gerencia perfis", ALL, using(is_manager())) e isso comprovadamente
-- funciona, trocamos pro mesmo mecanismo aqui -- em vez de tentar adivinhar
-- por que o join com profiles falha caso a caso, usamos o primitivo de
-- acesso que ja e a fonte da verdade no resto do sistema. Isso e aditivo
-- (soma via OR, nunca tira acesso) e resolve de forma geral pra qualquer
-- card e qualquer gestor, sem precisar checar agencia/streamer um a um.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

drop policy if exists "onboarding_material_check_progress_is_manager" on onboarding_material_check_progress;
create policy "onboarding_material_check_progress_is_manager" on onboarding_material_check_progress
  for all
  using (is_manager())
  with check (is_manager());

drop policy if exists "streamer_contact_logs_is_manager" on streamer_contact_logs;
create policy "streamer_contact_logs_is_manager" on streamer_contact_logs
  for all
  using (is_manager())
  with check (is_manager());

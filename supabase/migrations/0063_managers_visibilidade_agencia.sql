-- ============================================================================
-- Corrige o relato de gestor de que, ao "Enviar demanda para outra pessoa",
-- nem todo mundo da agencia aparece na lista (nem o dono/admin). A tabela
-- managers e anterior a esta pasta de migrations, entao nao sabemos ao
-- certo a policy de SELECT que ja existe nela hoje -- se for restrita
-- (ex: só a propria linha), qualquer tela que precise listar colegas
-- (Demandas, participante de evento, etc.) so consegue ver quem esta
-- logado. Esta policy e aditiva/permissiva: so amplia a visibilidade,
-- nunca restringe o que ja funcionava.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table managers enable row level security;

drop policy if exists "managers_select_same_agency" on managers;
create policy "managers_select_same_agency" on managers
  for select
  using (
    agency_id = (select agency_id from managers m2 where m2.id = auth.uid())
  );

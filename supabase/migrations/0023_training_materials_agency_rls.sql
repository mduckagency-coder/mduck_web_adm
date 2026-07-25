-- ============================================================================
-- Materiais (Recrutador e Gestor/Acompanhamento): agora qualquer gestor ou
-- recrutador pode editar, excluir e mover (mudar categoria/dia/order_index)
-- qualquer material da propria agencia, nao so os que ele mesmo criou --
-- inclusive materiais oficiais (autor coordenador/admin). Antes disso so
-- valia no app (isMine escondia os botoes); se a tabela ja tinha uma RLS
-- restringindo update/delete ao author_id, o Supabase vai barrar quem nao
-- for o autor mesmo com os botoes liberados na tela. Rode manualmente no
-- SQL Editor do Supabase. Aditivo: cria uma policy permissiva a mais,
-- agency-scoped, no mesmo padrao das demais tabelas do projeto -- nao
-- remove nenhuma policy existente.
-- ============================================================================
alter table training_materials enable row level security;

drop policy if exists "training_materials_agency" on training_materials;
create policy "training_materials_agency" on training_materials
  for all using (
    agency_id = (select agency_id from managers where id = auth.uid())
  )
  with check (
    agency_id = (select agency_id from managers where id = auth.uid())
  );

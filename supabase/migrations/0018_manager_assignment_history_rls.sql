-- ============================================================================
-- Corrige a RLS de manager_assignment_history: estava bloqueando insert
-- quando quem grava o vinculo (recrutador, ao "Vincular Streamer" ou no
-- handoff) nao e o proprio gestor sendo atribuido -- erro "new row
-- violates row-level security policy" (42501). Idem para leitura (CRM e
-- Curriculo do Streamer mostram esse historico independente de quem esta
-- logado). Rode manualmente no SQL Editor do Supabase. Aditivo: cria uma
-- policy permissiva a mais, agency-scoped, no mesmo padrao das demais
-- tabelas do projeto -- nao remove nenhuma policy existente.
-- ============================================================================
alter table manager_assignment_history enable row level security;

drop policy if exists "manager_assignment_history_agency" on manager_assignment_history;
create policy "manager_assignment_history_agency" on manager_assignment_history
  for all using (
    exists (
      select 1 from managers m
      where m.id = manager_assignment_history.manager_id
      and m.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from managers m
      where m.id = manager_assignment_history.manager_id
      and m.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

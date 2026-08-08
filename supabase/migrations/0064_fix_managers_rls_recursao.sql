-- ============================================================================
-- Corrige a policy de managers criada na migration 0063: uma policy em
-- "managers" que consulta "managers" de novo pra achar a propria linha fica
-- presa reavaliando a mesma regra (a subconsulta tambem esta sujeita a RLS
-- da mesma tabela). Isso derrubou a visibilidade em varias telas -- nao so
-- em managers, mas em QUALQUER outra tabela cuja policy faca
-- "select agency_id from managers where id = auth.uid()" (calendario,
-- demandas, materiais, onboarding, inventario -- e sao 28 tabelas assim),
-- porque essa subconsulta tambem esbarra na policy quebrada de managers.
--
-- Correcao: isolar a busca da propria agencia numa funcao SECURITY DEFINER
-- (roda ignorando RLS por dentro), quebrando o auto-referenciamento.
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

create or replace function my_manager_agency_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select agency_id from managers where id = auth.uid();
$$;

drop policy if exists "managers_select_same_agency" on managers;
create policy "managers_select_same_agency" on managers
  for select
  using (agency_id = my_manager_agency_id());

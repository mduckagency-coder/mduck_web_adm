-- ============================================================================
-- Profiles - Marca de criacao manual (Novo Agenciado)
-- Rode manualmente no SQL Editor do Supabase (mesmo padrao das migrations
-- anteriores).
--
-- Problema: o dialogo "Novo Agenciado" (Kanban de Onboarding do Gestor) cria
-- uma linha em profiles sem passar pela planilha oficial. Os dashboards de
-- "novos agenciados do mes" (Home Central e Dashboard da Equipe de
-- Recrutamento) contavam qualquer linha de profiles pelo joined_at do mes,
-- entao esses cadastros manuais inflavam o numero antes de serem confirmados
-- (ou nunca confirmados) pela planilha.
--
-- Aditivo: seguro rodar mesmo que a coluna ja exista. Nao apaga nem altera
-- dados existentes (default false preserva profiles ja cadastrados, que
-- vieram todos da planilha ate hoje).
-- ============================================================================

alter table profiles add column if not exists created_manually boolean not null default false;

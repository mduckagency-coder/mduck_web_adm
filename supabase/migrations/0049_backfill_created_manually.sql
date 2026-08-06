-- ============================================================================
-- Backfill: marca como created_manually os profiles criados manualmente
-- ("Novo Agenciado") ANTES da migration 0048 existir, que por isso nunca
-- receberam a marca e continuam inflando os dashboards de "novos
-- agenciados do mes" (Home Central e Dashboard da Equipe de Recrutamento).
-- Rode manualmente no SQL Editor do Supabase, depois da 0048.
--
-- Criterio: nunca passou por nenhuma das duas planilhas oficiais
-- (tiktok_username so e preenchido pela importacao de metricas;
-- tiktok_agent_email/agent_relationship_date so pela importacao de vinculo
-- de agente) e tem um gestor atribuido (assigned_manager_id), que so
-- acontece via "Novo Agenciado" ou handoff manual -- combinado com nunca
-- ter passado pela planilha, isola exatamente os cadastros manuais.
--
-- Rode primeiro o SELECT abaixo pra conferir a lista antes do UPDATE.
-- ============================================================================

-- select id, display_name, joined_at, tiktok_creator_id, assigned_manager_id
-- from profiles
-- where created_manually = false
--   and tiktok_username is null
--   and tiktok_agent_email is null
--   and agent_relationship_date is null
--   and assigned_manager_id is not null
-- order by joined_at;

update profiles
set created_manually = true
where created_manually = false
  and tiktok_username is null
  and tiktok_agent_email is null
  and agent_relationship_date is null
  and assigned_manager_id is not null;

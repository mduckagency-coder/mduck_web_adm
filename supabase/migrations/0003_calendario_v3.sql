-- ============================================================================
-- Modulo Calendario - Etapa 2.1
-- Aditivo: seguro rodar mesmo com as migrations anteriores ja aplicadas.
-- Rode manualmente no SQL Editor do Supabase.
--
-- Cada categoria agora define para quem ela e relevante (Agencia, Streamer
-- ou Ambos), usado para filtrar a lista de categorias conforme o escopo
-- escolhido no evento (Agencia/Streamer).
-- ============================================================================

alter table event_categories add column if not exists scope text not null default 'ambos' check (scope in ('agencia', 'streamer', 'ambos'));

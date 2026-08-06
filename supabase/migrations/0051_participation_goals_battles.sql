-- ============================================================================
-- Participacoes de programa - meta de batalhas
-- Rode manualmente no SQL Editor do Supabase.
--
-- A missao definida em "Incluir participacao" (aba Participantes) passa a
-- aceitar tambem uma meta de batalhas por mes, junto de dias/horas/
-- diamantes. Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

alter table program_participation_goals add column if not exists target_battles int;

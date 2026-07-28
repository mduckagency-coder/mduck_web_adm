-- ============================================================================
-- Corrige "column streamer_stat_snapshots.days_live does not exist": a
-- tabela de snapshots diarios nunca ganhou essa coluna (so a tabela de
-- totais, streamer_stats, tem days_live) -- por isso qualquer programa que
-- usa periodo "mes atual/anterior/mes atual ou anterior" (agora quase todos,
-- depois da 0037) falhava ao sincronizar. Rode manualmente no SQL Editor do
-- Supabase. Aditivo/idempotente.
-- ============================================================================
alter table streamer_stat_snapshots add column if not exists days_live int;

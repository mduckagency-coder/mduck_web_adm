-- ============================================================================
-- Repeticao mensal de demandas. Ao criar uma demanda com prazo e marcar
-- "Repetir todo mes", o app gera de uma vez as proximas 12 ocorrencias
-- (uma por mes, no mesmo dia do prazo original -- ajustado para o ultimo
-- dia do mes quando o mes seguinte for mais curto), todas com o mesmo
-- serie_id para poderem ser identificadas como parte da mesma serie.
--
-- Nao ha job automatico gerando novas ocorrencias além dessas 12; se
-- precisar estender, crie uma nova demanda recorrente a partir da ultima
-- ocorrencia.
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo: nao altera nem
-- apaga dados existentes.
-- ============================================================================
alter table demandas add column if not exists repete_mensalmente boolean not null default false;
alter table demandas add column if not exists serie_id uuid;

create index if not exists idx_demandas_serie on demandas(serie_id);

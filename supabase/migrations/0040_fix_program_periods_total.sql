-- ============================================================================
-- Corrige entrada de streamers nos Programas de Desenvolvimento.
--
-- Causa raiz: os programas padrao (Novatos, Veteranos, Top Ducker 80k,
-- Programa 150k, Elite...) nasceram com diamonds_period =
-- "mes_atual_ou_anterior", que exige um snapshot diario (streamer_stat_
-- snapshots) capturado ANTES do inicio do mes pra calcular o ganho do mes --
-- e esse snapshot so e capturado sob demanda (ao abrir a aba do programa,
-- sem tarefa agendada). Numa agencia que nao abre esses programas todo santo
-- dia, nunca existe um snapshot "de antes do mes", o ganho fica sempre nulo,
-- e ninguem nunca e elegivel -- mesmo com os criterios certos.
--
-- Fix: troca o periodo para "total", que usa o valor atual/corrente de
-- streamer_stats.diamonds diretamente (mesma fonte, ja confiavel, que
-- alimenta as abas de Metricas Streamers). Sem depender de historico de
-- snapshot nenhum.
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente: so
-- reescreve as 3 chaves de periodo dentro do criteria jsonb, sem apagar
-- nenhum outro campo.
-- ============================================================================
update development_programs
set criteria = jsonb_set(
  jsonb_set(
    jsonb_set(coalesce(criteria, '{}'::jsonb), '{diamonds_period}', '"total"'),
    '{hours_period}', '"total"'
  ),
  '{days_validated_period}', '"total"'
)
where criteria is not null
  and (
    criteria->>'diamonds_period' is distinct from 'total'
    or criteria->>'hours_period' is distinct from 'total'
    or criteria->>'days_validated_period' is distinct from 'total'
  );

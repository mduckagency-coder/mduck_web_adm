-- Premiacoes passam a poder ser marcadas com o mes de referencia (period_key,
-- formato "YYYY-MM"), independente da data em que foram criadas -- usado pela
-- aba Premiacoes pra filtrar "so este mes" vs "todos os meses". Registros
-- antigos ficam com period_key nulo e continuam aparecendo em "Todos os
-- meses" ate serem editados.
alter table program_awards add column if not exists period_key text;

create index if not exists program_awards_period_key_idx
  on program_awards (program_id, period_key);

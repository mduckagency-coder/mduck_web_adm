-- ============================================================================
-- Correcao pontual (rodar uma vez): a planilha de SETEMBRO foi importada em
-- 01/10 (antes do period_key existir), e a 0092 marcou esses numeros como
-- "2026-10" pela data. Quem nao veio na planilha de OUTUBRO (02/10 ~06h17)
-- ficou com setembro aparecendo como outubro (ex.: lidiherold0,
-- biancagoulart12, Willyane).
--
-- Linhas de outubro que nao foram tocadas desde 01/10 sao de setembro:
-- volta o period_key pra 2026-09 e roda a virada (guarda em monthly_stats
-- se faltar e zera o mes atual). Daqui pra frente a importacao grava o mes
-- da propria planilha, entao isso nao se repete.
-- ============================================================================

update streamer_stats
set period_key = '2026-09'
where period_key = '2026-10'
  and updated_at < timestamptz '2026-10-02 00:00:00-03';

select virar_mes_streamer_stats();

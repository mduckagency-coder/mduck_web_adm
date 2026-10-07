-- ============================================================================
-- Max Entrada: configuracao (engrenagem na pagina Max Entrada do painel).
--
-- 1. Libera a LEITURA de max_state_rules pro app do streamer. Sem isso o app
--    nunca conseguia ler os dias configurados e usava os valores fixos do
--    codigo.
-- 2. Liga/desliga da tela do Max ao abrir o app: app_settings, chave
--    'max_intro_enabled' (true/false). Sem a chave = ligado.
--
-- Regras usadas pelo app (max_state_rules, uma linha por estado):
--   inativo.min_days_without_live      a partir de X dias sem live
--   caveira.min_days_without_live      a partir de X dias sem live
--   constante.min_lives_this_month     minimo de dias com live no mes
--                                      (e ter feito live ontem ou hoje)
--   constante.extra_config.constante_min_streak_days
--                                      dias seguidos, usado se/quando houver
--                                      o dado de sequencia
-- A data da ultima live vem de profiles.last_live_at (Importacao TikTok).
--
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

drop policy if exists "max_state_rules_streamer_select" on max_state_rules;
create policy "max_state_rules_streamer_select" on max_state_rules
  for select using (
    agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

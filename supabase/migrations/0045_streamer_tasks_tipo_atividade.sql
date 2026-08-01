-- ============================================================================
-- Tipo de atividade da tarefa (Reuniao/Treinamento/Avaliacao/Recuperacao/
-- Meta semanal/Meta mensal/Graduacao/Follow-up) -- so um rotulo visual pra
-- colorir/filtrar a visualizacao Calendario da tela Streamers. Sem CHECK
-- rigido de proposito: sao so rotulos, mais facil de ajustar/adicionar tipo
-- novo depois sem precisar de outra migration. Nulo = tarefa "Geral"
-- (criada pelo campo simples "Proxima acao" do painel, sem tipo escolhido).
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table streamer_tasks
  add column if not exists activity_type text;

-- ============================================================================
-- Prioridade por atividade do cronograma (planejamento_atividades). Ate aqui
-- so existia prioridade no nivel da demanda/planejamento inteiro; agora cada
-- atividade pode ter a sua propria, exibida no cronograma e usada para
-- colorir o card quando a atividade aparece na visao Mes/Semana/Dia da
-- pagina de Demandas (junto com as demandas por prazo).
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo: nao altera nem apaga
-- dados existentes (atividades ja criadas recebem 'media' por padrao).
-- ============================================================================
alter table planejamento_atividades
  add column if not exists prioridade text not null default 'media' check (prioridade in ('alta', 'media', 'baixa'));

-- ============================================================================
-- Premiacoes de evento (Eventos > Premiacoes) passam a refletir
-- automaticamente no Financeiro RH > Entradas e Saidas, como uma saida
-- (despesa) na categoria "Premiacao de Evento". Nao usa o entry_type
-- 'premiacao' porque esse ja e reservado para bonificacao de colaborador
-- (folha de pagamento -- ver folhaTypes em dashboard_financeiro_page.dart);
-- misturar os dois corromperia o total da folha. event_award_id guarda o
-- vinculo com a premiacao de origem -- apagar a premiacao remove o
-- lancamento espelhado junto (on delete cascade).
-- ============================================================================
alter table financial_entries add column if not exists event_award_id uuid references event_awards(id) on delete cascade;
create index if not exists idx_financial_entries_event_award on financial_entries(event_award_id) where event_award_id is not null;

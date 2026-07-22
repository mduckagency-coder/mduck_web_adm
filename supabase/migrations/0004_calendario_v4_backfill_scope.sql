-- ============================================================================
-- Modulo Calendario - ajuste unico
-- As categorias padrao criadas ANTES da coluna `scope` existir foram
-- preenchidas com 'ambos' pela migration 0003 (valor default), entao nao
-- ficaram com o escopo pretendido (ex: "Treinamento Gamer" deveria ser so
-- Streamer). Este script corrige so quem ainda esta em 'ambos' (ou seja, nao
-- mexe em nada que voce ja tenha ajustado manualmente na engrenagem).
-- Seguro rodar mais de uma vez.
-- ============================================================================

update event_categories set scope = 'streamer' where key = 'batalha_oficial' and scope = 'ambos';
update event_categories set scope = 'agencia' where key = 'entrega_documentos' and scope = 'ambos';
update event_categories set scope = 'streamer' where key = 'treinamento_gamer' and scope = 'ambos';
update event_categories set scope = 'streamer' where key = 'treinamento_plataforma' and scope = 'ambos';
update event_categories set scope = 'agencia' where key = 'reuniao_interna_equipe' and scope = 'ambos';

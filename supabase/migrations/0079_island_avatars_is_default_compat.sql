-- ============================================================================
-- App ja implementado do lado do streamer procura uma coluna boolean
-- "is_default = true" pra achar o avatar padrao da agencia (erro visto:
-- "nenhum avatar ativo com is_default=true encontrado pra essa agencia") --
-- mas o admin (migration 0077) criou default_scope ('all'/'category'/null),
-- nao is_default. O app nunca vai achar nada com o schema atual.
--
-- Correcao: coluna gerada (sempre em sincronia sozinha, sem precisar mexer
-- no Dart) que espelha default_scope = 'all' -- resolve o caso "padrao pra
-- todos" imediatamente, sem esperar o app mudar nada.
--
-- IMPORTANTE: isso NAO cobre "padrao por categoria" (default_scope =
-- 'category') -- is_default e um flag unico e global, sem noção de
-- categoria. Pra "padrao por categoria" funcionar de verdade, o app
-- precisa ler default_scope + category_ids diretamente (ver
-- docs/ILHA_TOP_APP_SPEC.md secao 9.1) -- isso e trabalho do lado do app,
-- fora deste repositorio.
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table island_avatars drop column if exists is_default;
alter table island_avatars add column is_default boolean generated always as (coalesce(default_scope = 'all', false)) stored;

comment on column island_avatars.is_default is 'Gerada automaticamente a partir de default_scope = ''all'' -- existe so pra compatibilidade com o app do streamer, que le esse nome de coluna. Cobre so o padrao "para todos"; padrao "por categoria" precisa ler default_scope + category_ids direto (ver docs/ILHA_TOP_APP_SPEC.md).';

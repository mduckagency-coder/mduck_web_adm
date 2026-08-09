-- ============================================================================
-- 1) "Nao consigo excluir um avatar": streamer_islands.avatar_id referencia
-- island_avatars(id) sem ON DELETE definido (migration 0067) -- Postgres
-- bloqueia o delete (violacao de foreign key) sempre que algum streamer ja
-- tiver escolhido aquele avatar. Troca pra ON DELETE SET NULL: apagar o
-- avatar so desvincula quem tinha escolhido ele (volta a valer o avatar
-- padrao, ver item 2), sem bloquear a exclusao.
--
-- 2) Avatar padrao: pedido de ter uma opcao de avatar padrao (pra quando o
-- streamer ainda nao escolheu nenhum, ou perdeu o que tinha escolhido por
-- causa do item 1) -- padrao pra todos, ou padrao só pras categorias
-- selecionadas no proprio avatar (reaproveita a coluna category_ids que ja
-- existe pra "quem pode escolher").
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

do $$
declare
  c_name text;
begin
  select conname into c_name
  from pg_constraint
  where conrelid = 'streamer_islands'::regclass
    and confrelid = 'island_avatars'::regclass
    and contype = 'f';
  if c_name is not null then
    execute format('alter table streamer_islands drop constraint %I', c_name);
  end if;
end $$;

alter table streamer_islands
  add constraint streamer_islands_avatar_id_fkey
  foreign key (avatar_id) references island_avatars(id) on delete set null;

alter table island_avatars add column if not exists default_scope text;

alter table island_avatars drop constraint if exists island_avatars_default_scope_check;
alter table island_avatars add constraint island_avatars_default_scope_check check (default_scope is null or default_scope in ('all', 'category'));

comment on column island_avatars.default_scope is 'null (nao e padrao), ''all'' (avatar padrao pra qualquer streamer sem escolha) ou ''category'' (padrao so pras categorias em category_ids). So um avatar por agencia pode ter default_scope=''all''; por categoria, so um avatar por categoria pode ter default_scope=''category'' -- o admin (ilha_top_service.dart) cuida de desmarcar o anterior ao salvar um novo.';

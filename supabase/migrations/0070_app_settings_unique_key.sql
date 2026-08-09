-- ============================================================================
-- app_settings nunca teve uma constraint unica em (agency_id, key) -- so um
-- indice normal (ver 0060_app_settings_inventory_mascot.sql). Isso permite
-- duas linhas com a mesma chave pra mesma agencia (ex: duas telas salvando
-- "island_test_config" quase ao mesmo tempo), e o padrao de codigo
-- "select ... maybeSingle() -> insert ou update" quebra nesse caso com
-- PGRST116 ("multiple rows returned") -- exatamente o sintoma de "salvei e
-- nao aconteceu nada". Com a constraint, o codigo passa a usar upsert
-- (onConflict: agency_id,key), que e atomico e nao tem essa corrida.
--
-- Deduplica linhas existentes antes de criar a constraint (mantem a mais
-- recente por updated_at; empate exato desempata por ctid -- o identificador
-- interno de linha do Postgres, que sempre existe independente do nome da
-- coluna de PK da tabela).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente (o
-- "add constraint" da erro se rodar 2x -- nesse caso pode ignorar).
-- ============================================================================

delete from app_settings a using app_settings b
where a.agency_id = b.agency_id
  and a.key = b.key
  and a.updated_at < b.updated_at;

delete from app_settings a using app_settings b
where a.agency_id = b.agency_id
  and a.key = b.key
  and a.ctid < b.ctid;

alter table app_settings
  add constraint app_settings_agency_key_unique unique (agency_id, key);

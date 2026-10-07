-- ============================================================================
-- Home do app: "Métricas atualizadas em DD/MM às HH:MM".
-- Data da ultima importacao de METRICAS concluida da agencia do streamer
-- (tiktok_imports, que o streamer nao le direto).
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================
create or replace function app_metrics_updated_at()
returns timestamptz
language sql stable security definer
set search_path = public
as $$
  select max(i.processed_at)
  from tiktok_imports i
  where i.agency_id = (select p.agency_id from profiles p where p.auth_user_id = auth.uid() limit 1)
    and i.status = 'concluido'
    and coalesce(i.import_type, 'metricas') = 'metricas';
$$;
grant execute on function app_metrics_updated_at() to authenticated;

notify pgrst, 'reload schema';

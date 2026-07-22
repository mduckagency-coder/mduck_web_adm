-- ============================================================================
-- Modulo Calendario - Etapa 2
-- Aditivo: seguro rodar mesmo com a Etapa 1 (0001_calendario.sql) ja aplicada.
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table calendar_events add column if not exists scope text not null default 'agencia' check (scope in ('agencia', 'streamer'));
alter table calendar_events add column if not exists visibility text not null default 'equipe' check (visibility in ('todos', 'equipe', 'selecionados'));
create index if not exists idx_calendar_events_scope on calendar_events(agency_id, scope);

-- ============================================================================
-- Programas de Desenvolvimento - permitir excluir os programas padrao
-- Rode manualmente no SQL Editor do Supabase.
--
-- seedDevelopmentPrograms (program_phase_service.dart) recria sozinho
-- qualquer um dos 12 programas fixos que nao existir mais pra agencia,
-- toda vez que a tela de Programas abre -- por isso ate agora o botao
-- Excluir era bloqueado pra eles (excluir so faria reaparecer na proxima
-- abertura). Essa tabela registra "essa agencia excluiu esse programa
-- fixo de proposito", pra o seed parar de recriar -- assim o gestor pode
-- excluir qualquer programa, fixo ou nao.
--
-- Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

create table if not exists development_programs_dismissed (
  agency_id uuid not null,
  program_key text not null,
  dismissed_by uuid references managers(id),
  dismissed_at timestamptz not null default now(),
  primary key (agency_id, program_key)
);

alter table development_programs_dismissed enable row level security;
drop policy if exists "development_programs_dismissed_agency" on development_programs_dismissed;
create policy "development_programs_dismissed_agency" on development_programs_dismissed for all using (
  agency_id = (select agency_id from managers where id = auth.uid())
) with check (
  agency_id = (select agency_id from managers where id = auth.uid())
);

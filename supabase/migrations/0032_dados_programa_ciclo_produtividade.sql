-- ============================================================================
-- Dados do programa (status/datas/cor/icone/responsaveis), dados e
-- indicadores do ciclo (nome/observacoes), e recursos de produtividade na
-- lista de Participantes (filtros salvos, colunas visiveis persistidas).
-- Rode manualmente no SQL Editor do Supabase. Aditivo: nao altera nem apaga
-- dados existentes.
-- ============================================================================

-- Status de 3 estados (Ativo/Pausado/Encerrado), substituindo o antigo bool
-- is_active nas telas -- a coluna is_active fica no banco (nunca apagamos
-- coluna), so para de ser usada pelo app.
alter table development_programs add column if not exists status text not null default 'ativo' check (status in ('ativo', 'pausado', 'encerrado'));
update development_programs set status = case when is_active then 'ativo' else 'encerrado' end where status = 'ativo';

alter table development_programs add column if not exists start_date date;
alter table development_programs add column if not exists end_date date;
alter table development_programs add column if not exists color text not null default '#7A0BD4';
alter table development_programs add column if not exists icon_key text;

-- Responsaveis multiplos por programa (mesmo espirito de
-- streamer_phase_progress_managers, migration 0010). Backfill: 1 linha por
-- programa que ja tinha responsible_manager_id preenchido.
create table if not exists development_program_managers (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references development_programs(id) on delete cascade,
  manager_id uuid not null references managers(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (program_id, manager_id)
);
create index if not exists idx_development_program_managers_program on development_program_managers(program_id);

insert into development_program_managers (program_id, manager_id)
  select id, responsible_manager_id from development_programs
  where responsible_manager_id is not null
  on conflict (program_id, manager_id) do nothing;

alter table development_program_managers enable row level security;
drop policy if exists "development_program_managers_agency" on development_program_managers;
create policy "development_program_managers_agency" on development_program_managers for all using (
  exists (select 1 from development_programs p where p.id = development_program_managers.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
) with check (
  exists (select 1 from development_programs p where p.id = development_program_managers.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
);

-- Nome customizado do ciclo (opcional -- cai pro period_label automatico
-- quando vazio) e observacoes gerais (distinto da descricao da missao).
alter table campaign_cycles add column if not exists name text;
alter table campaign_cycles add column if not exists notes text;

-- Filtros salvos da aba Participantes: pessoais do gestor, reutilizaveis em
-- qualquer um dos 6 programas (o conjunto de filtro/ordenacao e o mesmo em
-- todos).
create table if not exists program_saved_filters (
  id uuid primary key default gen_random_uuid(),
  manager_id uuid not null references managers(id) on delete cascade,
  name text not null,
  filter_key text,
  sort_key text,
  search_term text,
  created_at timestamptz not null default now()
);
create index if not exists idx_program_saved_filters_manager on program_saved_filters(manager_id);

alter table program_saved_filters enable row level security;
drop policy if exists "program_saved_filters_own" on program_saved_filters;
create policy "program_saved_filters_own" on program_saved_filters for all using (
  manager_id = auth.uid()
) with check (
  manager_id = auth.uid()
);

-- Preferencia de colunas visiveis na visualizacao em Tabela (Participantes)
-- -- por gestor, reutilizada em qualquer programa. null = mostra todas.
alter table managers add column if not exists participant_table_columns text[];

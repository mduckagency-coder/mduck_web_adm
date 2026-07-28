-- ============================================================================
-- Modulo Gestao > Demandas + Planejamento.
--
-- Demandas: tarefas que qualquer gestor (ou a administracao) pode enviar
-- para qualquer outro gestor da mesma agencia (inclusive para si mesmo).
-- Quem cria (criado_por) pode ser diferente de quem recebe (responsavel_id).
-- Ao criar, o responsavel recebe uma manager_notifications (ver
-- lib/features/gestao/demanda_notifications.dart).
--
-- Planejamento: quando o gestor decide organizar a execucao de uma demanda,
-- clica em "Planejar execucao" e o app cria um planejamento vinculado
-- (1 por demanda - demanda_id e unique), copiando titulo/descricao/
-- prioridade/categoria da demanda (para nao precisar digitar de novo).
-- Dentro do planejamento, o Cronograma tem atividades (com data/hora
-- opcional) que aparecem no calendario do proprio planejamento -- a
-- demanda original nunca aparece nesse calendario, so as atividades.
--
-- Rode manualmente no SQL Editor do Supabase. Aditivo: nao altera nem
-- apaga dados existentes.
-- ============================================================================

create table if not exists demandas (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  titulo text not null,
  descricao text not null default '',
  prioridade text not null default 'media' check (prioridade in ('alta', 'media', 'baixa')),
  categoria text not null default 'Geral',
  icone text not null default 'flag',
  prazo timestamptz,
  status text not null default 'nao_iniciada' check (status in ('nao_iniciada', 'em_andamento', 'concluida')),
  criado_por uuid not null references managers(id),
  responsavel_id uuid not null references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_demandas_agency on demandas(agency_id);
create index if not exists idx_demandas_responsavel on demandas(responsavel_id);
create index if not exists idx_demandas_criado_por on demandas(criado_por);

alter table demandas enable row level security;
drop policy if exists "demandas_agency" on demandas;
create policy "demandas_agency" on demandas for all using (
  agency_id = (select agency_id from managers where id = auth.uid())
) with check (
  agency_id = (select agency_id from managers where id = auth.uid())
);

-- Observacoes (mural de notas livres) de uma demanda, em ordem cronologica.
create table if not exists demanda_observacoes (
  id uuid primary key default gen_random_uuid(),
  demanda_id uuid not null references demandas(id) on delete cascade,
  autor_id uuid not null references managers(id),
  texto text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_demanda_observacoes_demanda on demanda_observacoes(demanda_id, created_at);

alter table demanda_observacoes enable row level security;
drop policy if exists "demanda_observacoes_agency" on demanda_observacoes;
create policy "demanda_observacoes_agency" on demanda_observacoes for all using (
  exists (select 1 from demandas d where d.id = demanda_observacoes.demanda_id and d.agency_id = (select agency_id from managers where id = auth.uid()))
) with check (
  exists (select 1 from demandas d where d.id = demanda_observacoes.demanda_id and d.agency_id = (select agency_id from managers where id = auth.uid()))
);

-- Planejamento: 1 por demanda (demanda_id unique). Copia campos da demanda
-- no momento da criacao, para o gestor nao precisar redigitar nada.
create table if not exists planejamentos (
  id uuid primary key default gen_random_uuid(),
  demanda_id uuid not null unique references demandas(id) on delete cascade,
  titulo text not null,
  descricao text not null default '',
  prioridade text not null,
  categoria text not null,
  created_by uuid not null references managers(id),
  created_at timestamptz not null default now()
);

alter table planejamentos enable row level security;
drop policy if exists "planejamentos_agency" on planejamentos;
create policy "planejamentos_agency" on planejamentos for all using (
  exists (select 1 from demandas d where d.id = planejamentos.demanda_id and d.agency_id = (select agency_id from managers where id = auth.uid()))
) with check (
  exists (select 1 from demandas d where d.id = planejamentos.demanda_id and d.agency_id = (select agency_id from managers where id = auth.uid()))
);

-- Cronograma: atividades do planejamento. So atividades com "data" aparecem
-- no calendario do planejamento (a demanda original nunca aparece nele).
create table if not exists planejamento_atividades (
  id uuid primary key default gen_random_uuid(),
  planejamento_id uuid not null references planejamentos(id) on delete cascade,
  descricao text not null,
  data date not null,
  hora time,
  concluida boolean not null default false,
  created_by uuid not null references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_planejamento_atividades_planejamento on planejamento_atividades(planejamento_id);
create index if not exists idx_planejamento_atividades_data on planejamento_atividades(data);

alter table planejamento_atividades enable row level security;
drop policy if exists "planejamento_atividades_agency" on planejamento_atividades;
create policy "planejamento_atividades_agency" on planejamento_atividades for all using (
  exists (
    select 1 from planejamentos p
    join demandas d on d.id = p.demanda_id
    where p.id = planejamento_atividades.planejamento_id
    and d.agency_id = (select agency_id from managers where id = auth.uid())
  )
) with check (
  exists (
    select 1 from planejamentos p
    join demandas d on d.id = p.demanda_id
    where p.id = planejamento_atividades.planejamento_id
    and d.agency_id = (select agency_id from managers where id = auth.uid())
  )
);

-- Observacoes de uma atividade especifica do cronograma (mesmo padrao das
-- observacoes da demanda).
create table if not exists planejamento_atividade_observacoes (
  id uuid primary key default gen_random_uuid(),
  atividade_id uuid not null references planejamento_atividades(id) on delete cascade,
  autor_id uuid not null references managers(id),
  texto text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_planejamento_atividade_observacoes_atividade on planejamento_atividade_observacoes(atividade_id, created_at);

alter table planejamento_atividade_observacoes enable row level security;
drop policy if exists "planejamento_atividade_observacoes_agency" on planejamento_atividade_observacoes;
create policy "planejamento_atividade_observacoes_agency" on planejamento_atividade_observacoes for all using (
  exists (
    select 1 from planejamento_atividades a
    join planejamentos p on p.id = a.planejamento_id
    join demandas d on d.id = p.demanda_id
    where a.id = planejamento_atividade_observacoes.atividade_id
    and d.agency_id = (select agency_id from managers where id = auth.uid())
  )
) with check (
  exists (
    select 1 from planejamento_atividades a
    join planejamentos p on p.id = a.planejamento_id
    join demandas d on d.id = p.demanda_id
    where a.id = planejamento_atividade_observacoes.atividade_id
    and d.agency_id = (select agency_id from managers where id = auth.uid())
  )
);

-- ============================================================================
-- Programas de Desenvolvimento - Participacoes manuais (missoes)
-- Rode manualmente no SQL Editor do Supabase (mesmo padrao das anteriores).
--
-- A aba Participantes trocou o motor automatico de elegibilidade
-- (development_programs.criteria / streamer_phase_progress) por um fluxo
-- manual: o gestor filtra streamers por tempo de agencia e faixa de
-- diamantes do mes passado, seleciona varios de uma vez e define uma
-- "missao" (metas de dias/horas/diamantes, podendo se estender por N meses)
-- aplicada a todos os selecionados. O cumprimento de cada mes e confirmado
-- manualmente pelo gestor -- o sistema so calcula e mostra o progresso como
-- referencia (reaproveita streamer_stats/monthly_stats, as mesmas fontes de
-- program_monthly_stats_service.dart).
--
-- Tabelas novas, isoladas de streamer_phase_progress: aquela tabela e
-- modelada em torno de um Kanban com outcome fechado por CHECK a uma unica
-- decisao terminal (aprovado/revisao/desligado/graduado), incompativel com
-- "N meses, cada um com seu proprio veredito". streamer_phase_progress
-- continua existindo e sendo usada pela aba Fluxo e por quem ainda depender
-- da engine de criterios -- nao mexemos nela aqui.
--
-- Aditivo: seguro rodar mesmo que as tabelas ja existam. Nao apaga nem
-- altera dados existentes.
-- ============================================================================

create table if not exists program_participations (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references development_programs(id) on delete cascade,
  streamer_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'ativo' check (status in ('ativo', 'concluido', 'removido')),

  -- "A que ele vai concorrer" / o presente que vai ganhar -- confirmado
  -- pelo gestor como o MESMO campo, texto livre por participacao.
  prize_description text,
  notes text,

  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  removed_by uuid references managers(id)
);

-- So uma participacao ATIVA por streamer/programa -- readicionar depois de
-- removido cria uma linha nova (historico preservado, nunca apaga).
create unique index if not exists uq_program_participations_active
  on program_participations(program_id, streamer_id) where status = 'ativo';
create index if not exists idx_program_participations_program
  on program_participations(program_id, status);
create index if not exists idx_program_participations_streamer
  on program_participations(streamer_id);

alter table program_participations enable row level security;
drop policy if exists "program_participations_agency" on program_participations;
create policy "program_participations_agency" on program_participations for all using (
  exists (select 1 from development_programs p where p.id = program_participations.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
) with check (
  exists (select 1 from development_programs p where p.id = program_participations.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
);

-- Uma linha por mes da missao. month_index = ordem dentro da participacao
-- (1, 2, 3...), period_key = mes de calendario real ('YYYY-MM') que esse mes
-- da missao representa, calculado UMA VEZ na criacao (mes 1 = mes corrente
-- no momento da criacao, mes 2 = mes seguinte, etc.) e congelado -- assim o
-- progresso sempre sabe se deve olhar streamer_stats (period_key = mes
-- corrente real) ou monthly_stats (period_key no passado, mes ja fechado)
-- sem ambiguidade, do mesmo jeito que resolveMonthlySnapshots ja resolve
-- mes atual/anterior em program_monthly_stats_service.dart.
create table if not exists program_participation_goals (
  id uuid primary key default gen_random_uuid(),
  participation_id uuid not null references program_participations(id) on delete cascade,
  month_index int not null check (month_index >= 1),
  period_key text not null,

  target_days int,
  target_hours numeric,
  target_diamonds numeric,

  outcome text not null default 'pendente' check (outcome in ('pendente', 'cumpriu', 'nao_cumprido')),
  confirmed_at timestamptz,
  confirmed_by uuid references managers(id),

  created_at timestamptz not null default now(),
  unique (participation_id, month_index)
);
create index if not exists idx_program_participation_goals_participation
  on program_participation_goals(participation_id);

alter table program_participation_goals enable row level security;
drop policy if exists "program_participation_goals_agency" on program_participation_goals;
create policy "program_participation_goals_agency" on program_participation_goals for all using (
  exists (
    select 1 from program_participations pp
    join development_programs p on p.id = pp.program_id
    where pp.id = program_participation_goals.participation_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
  )
) with check (
  exists (
    select 1 from program_participations pp
    join development_programs p on p.id = pp.program_id
    where pp.id = program_participation_goals.participation_id
      and p.agency_id = (select agency_id from managers where id = auth.uid())
  )
);

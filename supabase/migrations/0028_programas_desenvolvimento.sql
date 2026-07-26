-- ============================================================================
-- Programas de Desenvolvimento: novo modulo que representa toda a jornada
-- do streamer na agencia (Onboarding 15 -> Onboarding 30 -> Novatos ->
-- Top Ducker 80k -> Programa 150k -> Elite). Reaproveita o motor ja
-- existente do Onboarding 0-15 Dias (streamer_phase_stages/checklist/
-- progress/history, particionado por phase_key) -- cada programa usa sua
-- propria phase_key nessas MESMAS tabelas, sem duplicar Kanban/checklist/
-- historico. As linhas de "onboarding_0_15" existentes nao sao alteradas
-- (so ganham a nova coluna abaixo, com valor padrao seguro).
--
-- development_programs guarda os 6 programas fixos (nome, descricao,
-- criterios editaveis em jsonb, e a cadeia de progressao via
-- next_program_key/graduate_program_key). Rode manualmente no SQL Editor
-- do Supabase. Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

-- Heart Me: campo manual novo (a importacao do TikTok hoje nao traz esse
-- dado -- so diamantes/horas/dias/batalhas/status).
alter table streamer_stats add column if not exists heart_me numeric;

-- Identifica qual etapa de um fluxo e a "decisao final" (mostra os botoes
-- Aprovar/Graduar/Encerrar parceria), em vez do antigo hardcode de string
-- "avaliacao" -- assim qualquer programa (incluindo os configurados pelo
-- usuario depois) pode marcar sua propria etapa de decisao.
alter table streamer_phase_stages add column if not exists is_evaluation_stage boolean not null default false;
update streamer_phase_stages set is_evaluation_stage = true where phase_key = 'onboarding_0_15' and stage_key = 'avaliacao';

-- "graduado" e uma nova saida da avaliacao final (alem de aprovado/revisao/
-- desligado): o streamer vai para um programa de destaque diferente do
-- proximo programa padrao (ex: Novatos Destaque em vez de Novatos).
alter table streamer_phase_progress drop constraint if exists streamer_phase_progress_outcome_check;
alter table streamer_phase_progress add constraint streamer_phase_progress_outcome_check check (outcome in ('aprovado', 'revisao', 'desligado', 'graduado'));

-- Os 6 programas fixos. criteria guarda tudo que for configuravel e
-- opcional (chave ausente/nula = criterio desativado): min_days, min_hours,
-- min_diamonds, min_heart_me, min_battles, category_ids (array de uuid),
-- required_material_ids (array de uuid). Um unico jsonb evita tabela extra
-- e segue o mesmo padrao ja usado em event_awards.items.
create table if not exists development_programs (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  program_key text not null,
  order_index int not null default 999,
  name text not null,
  description text,
  objective text,
  awards_description text,
  responsible_manager_id uuid references managers(id),
  default_message text,
  next_program_key text,
  graduate_program_key text,
  is_active boolean not null default true,
  criteria jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agency_id, program_key)
);
create index if not exists idx_development_programs_agency on development_programs(agency_id, order_index);

alter table development_programs enable row level security;
drop policy if exists "development_programs_agency" on development_programs;
create policy "development_programs_agency" on development_programs for all using (
  agency_id = (select agency_id from managers where id = auth.uid())
) with check (
  agency_id = (select agency_id from managers where id = auth.uid())
);

-- Premiacoes de programa (ex: entrega de kit ao concluir o Onboarding 30) --
-- mesmo espirito de event_awards, mas sem vinculo a um Evento especifico.
create table if not exists program_awards (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references development_programs(id) on delete cascade,
  streamer_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  reason text,
  status text not null default 'pendente' check (status in ('pendente', 'entregue')),
  created_at timestamptz not null default now(),
  delivered_at timestamptz,
  created_by uuid references managers(id)
);
create index if not exists idx_program_awards_program on program_awards(program_id);
create index if not exists idx_program_awards_streamer on program_awards(streamer_id);

alter table program_awards enable row level security;
drop policy if exists "program_awards_agency" on program_awards;
create policy "program_awards_agency" on program_awards for all using (
  exists (select 1 from development_programs p where p.id = program_awards.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
) with check (
  exists (select 1 from development_programs p where p.id = program_awards.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
);

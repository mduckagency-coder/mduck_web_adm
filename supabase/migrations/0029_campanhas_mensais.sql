-- ============================================================================
-- Campanhas Mensais: dentro de cada Programa de Desenvolvimento, o gestor
-- inicia um ciclo mensal ("campanha") -- o sistema busca automaticamente os
-- streamers elegiveis (contra os criterios do programa + a missao do mes),
-- gera a lista de participantes (pronta pra copiar pro Backstage do TikTok,
-- que e manual), acompanha oportunidades/risco durante o mes e, ao concluir,
-- gera um relatorio e promove quem o gestor confirmar.
--
-- A elegibilidade de campanha NAO depende do Fluxo/Kanban
-- (streamer_phase_progress) -- calculada direto contra os criterios, pra
-- funcionar mesmo em programas que ainda nao tem etapas configuradas.
-- ============================================================================

create table if not exists campaign_cycles (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references development_programs(id) on delete cascade,
  period_key text not null,
  period_label text not null,
  status text not null default 'em_andamento' check (status in ('em_andamento', 'finalizado')),
  mission_title text,
  mission_description text,
  mission_criteria jsonb not null default '{}'::jsonb,
  default_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_by uuid references managers(id),
  report jsonb,
  unique (program_id, period_key)
);
create index if not exists idx_campaign_cycles_program on campaign_cycles(program_id, started_at desc);

alter table campaign_cycles enable row level security;
drop policy if exists "campaign_cycles_agency" on campaign_cycles;
create policy "campaign_cycles_agency" on campaign_cycles for all using (
  exists (select 1 from development_programs p where p.id = campaign_cycles.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
) with check (
  exists (select 1 from development_programs p where p.id = campaign_cycles.program_id and p.agency_id = (select agency_id from managers where id = auth.uid()))
);

-- Lista de participantes fixada no momento em que o ciclo comeca (nao muda
-- sozinha durante o mes -- so o status calculado ao vivo na tela muda).
create table if not exists campaign_cycle_participants (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references campaign_cycles(id) on delete cascade,
  streamer_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  final_status text check (final_status in ('concluido', 'nao_concluido')),
  unique (cycle_id, streamer_id)
);
create index if not exists idx_campaign_cycle_participants_cycle on campaign_cycle_participants(cycle_id);
create index if not exists idx_campaign_cycle_participants_streamer on campaign_cycle_participants(streamer_id);

alter table campaign_cycle_participants enable row level security;
drop policy if exists "campaign_cycle_participants_agency" on campaign_cycle_participants;
create policy "campaign_cycle_participants_agency" on campaign_cycle_participants for all using (
  exists (
    select 1 from campaign_cycles c
    join development_programs p on p.id = c.program_id
    where c.id = campaign_cycle_participants.cycle_id and p.agency_id = (select agency_id from managers where id = auth.uid())
  )
) with check (
  exists (
    select 1 from campaign_cycles c
    join development_programs p on p.id = c.program_id
    where c.id = campaign_cycle_participants.cycle_id and p.agency_id = (select agency_id from managers where id = auth.uid())
  )
);

-- Checklist operacional do ciclo (seedado com o padrao ao criar o ciclo,
-- editavel: pode adicionar/remover itens de um ciclo especifico).
create table if not exists campaign_cycle_checklist (
  id uuid primary key default gen_random_uuid(),
  cycle_id uuid not null references campaign_cycles(id) on delete cascade,
  label text not null,
  done boolean not null default false,
  done_at timestamptz,
  order_index int not null default 999
);
create index if not exists idx_campaign_cycle_checklist_cycle on campaign_cycle_checklist(cycle_id);

alter table campaign_cycle_checklist enable row level security;
drop policy if exists "campaign_cycle_checklist_agency" on campaign_cycle_checklist;
create policy "campaign_cycle_checklist_agency" on campaign_cycle_checklist for all using (
  exists (
    select 1 from campaign_cycles c
    join development_programs p on p.id = c.program_id
    where c.id = campaign_cycle_checklist.cycle_id and p.agency_id = (select agency_id from managers where id = auth.uid())
  )
) with check (
  exists (
    select 1 from campaign_cycles c
    join development_programs p on p.id = c.program_id
    where c.id = campaign_cycle_checklist.cycle_id and p.agency_id = (select agency_id from managers where id = auth.uid())
  )
);

-- Premiacao/medalha entregue dentro de um ciclo especifico (pra contar no
-- relatorio de conclusao). Nullable: premiacoes fora de um ciclo continuam
-- funcionando como ja funcionavam.
alter table program_awards add column if not exists cycle_id uuid references campaign_cycles(id) on delete set null;
create index if not exists idx_program_awards_cycle on program_awards(cycle_id) where cycle_id is not null;

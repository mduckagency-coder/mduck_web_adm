-- ============================================================================
-- Refinamentos da aba Participantes (Programas de Desenvolvimento):
-- marcadores manuais, observacao fixada e snapshot diario (base dos
-- indicadores de evolucao semana a semana). Rode manualmente no SQL Editor
-- do Supabase. Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

-- Marcadores (⭐ Destaque, 🔥 Alto potencial, ⚠ Precisa de acompanhamento,
-- ❤ Muito engajado, 🎁 Premiacao especial) sao por participante NESTE
-- programa (mesma linha do card no Fluxo).
alter table streamer_phase_progress add column if not exists tags text[] not null default '{}';

-- Observacao fixada: sempre aparece no topo do resumo individual do
-- streamer dentro do programa.
alter table streamer_phase_progress add column if not exists pinned_note text;

-- Snapshot diario dos numeros do streamer -- capturado sob demanda (sem
-- tarefa agendada): toda vez que a aba Participantes/painel lateral e
-- aberta, se ainda nao existir um snapshot de hoje, ele e criado. Compara-se
-- o snapshot mais recente com o mais proximo de 7 dias atras pra gerar os
-- indicadores ▲/▼ de evolucao.
create table if not exists streamer_stat_snapshots (
  id uuid primary key default gen_random_uuid(),
  streamer_id uuid not null references profiles(id) on delete cascade,
  agency_id uuid not null,
  snapshot_date date not null default current_date,
  hours_live numeric,
  diamonds numeric,
  heart_me numeric,
  battles int,
  created_at timestamptz not null default now(),
  unique (streamer_id, snapshot_date)
);
create index if not exists idx_streamer_stat_snapshots_streamer on streamer_stat_snapshots(streamer_id, snapshot_date desc);

alter table streamer_stat_snapshots enable row level security;
drop policy if exists "streamer_stat_snapshots_agency" on streamer_stat_snapshots;
create policy "streamer_stat_snapshots_agency" on streamer_stat_snapshots for all using (
  agency_id = (select agency_id from managers where id = auth.uid())
) with check (
  agency_id = (select agency_id from managers where id = auth.uid())
);

-- ============================================================================
-- Participacoes de programa - quadro Fluxo baseado em participacoes
-- Rode manualmente no SQL Editor do Supabase.
--
-- A aba Fluxo passa a ser um quadro Kanban sobre program_participations (em
-- vez do motor antigo de streamer_phase_progress/criterios automaticos),
-- com 5 colunas: Em andamento e Nao conseguiu/Concluido sao calculadas
-- sozinhas a partir do outcome dos meses da missao; dai em diante
-- (Concluido -> Pendente de entrega -> Entregue) o gestor arrasta o card a
-- mao, e essa escolha fica gravada em delivery_status. Ao entrar em
-- "Entregue", o sistema registra a premiacao em program_awards (que ja
-- aparece sozinho na aba Premiacoes do programa e na aba "Programas de
-- Desenvolvimento" do CRM do streamer -- sem tabela nova pra isso).
--
-- Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

alter table program_participations add column if not exists delivery_status text check (delivery_status in ('pendente_entrega', 'entregue'));

alter table program_awards add column if not exists participation_id uuid references program_participations(id) on delete set null;
create index if not exists idx_program_awards_participation on program_awards(participation_id) where participation_id is not null;

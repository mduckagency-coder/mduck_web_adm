-- ============================================================================
-- Participacoes de programa - override manual de coluna + premiacao paga
-- Rode manualmente no SQL Editor do Supabase.
--
-- 1) delivery_status vira stage_override: em vez de so cobrir os 2 ultimos
-- estagios manuais (pendente_entrega/entregue), agora guarda a coluna
-- manual escolhida pelo gestor pra QUALQUER estagio do quadro Fluxo (o
-- gestor pode mover um card na mao se precisar, mesmo os que normalmente
-- sao calculados sozinhos). Null continua significando "automatico".
--
-- 2) "proximos_a_entrar" e um estagio novo: participacao cujo primeiro mes
-- da missao ainda nao comecou (agendada pra um mes futuro) -- usado quando
-- o gestor ja programa o streamer pro mes que vem e precisa lembrar disso.
--
-- 3) financial_entries.program_award_id -- mesmo padrao ja usado por
-- event_award_id (migration 0027_event_awards_financial_entries_link.sql):
-- premiacao de programa marcada como entregue com valor definido vira uma
-- saida (despesa) automatica em Financeiro RH > Entradas e Saidas.
--
-- Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

alter table program_participations drop constraint if exists program_participations_delivery_status_check;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_name = 'program_participations' and column_name = 'delivery_status'
  ) then
    alter table program_participations rename column delivery_status to stage_override;
  end if;
end $$;

alter table program_participations add column if not exists stage_override text;
alter table program_participations add constraint program_participations_stage_override_check
  check (stage_override in ('proximos_a_entrar', 'em_andamento', 'nao_conseguiu', 'concluido', 'pendente_entrega', 'entregue'));

alter table financial_entries add column if not exists program_award_id uuid references program_awards(id) on delete cascade;
create index if not exists idx_financial_entries_program_award on financial_entries(program_award_id) where program_award_id is not null;

-- ============================================================================
-- Premiacoes de evento (Eventos - Premiacoes): passa a poder vincular
-- (opcional) a um streamer oficial -- vinculado, a premiacao aparece
-- automaticamente na timeline do CRM dele (consulta direta por streamer_id,
-- sem duplicar dado em outra tabela). Sem vinculo continua permitido
-- (premiacao manual). Um registro agora suporta varios itens premiados
-- (ex: 1 iPhone + 2 vouchers) via items jsonb, e ganha previsao de entrega.
-- Vocabulario de status muda de pendente/comprado/entregue para
-- pendente/agendado/pago; delivered_at vira paid_at (data de pagamento,
-- preenchida ao marcar como pago). "Gestor responsavel" e "data de
-- cadastro" mostrados na tela reaproveitam created_by/created_at, que ja
-- existiam.
-- ============================================================================
alter table event_awards add column if not exists streamer_id uuid references profiles(id) on delete set null;
alter table event_awards add column if not exists expected_delivery_date date;
alter table event_awards add column if not exists items jsonb not null default '[]'::jsonb;

update event_awards set items = jsonb_build_array(jsonb_build_object('name', name, 'quantity', quantity, 'value', value))
where items = '[]'::jsonb;

do $$
begin
  if exists (select 1 from information_schema.columns where table_name = 'event_awards' and column_name = 'delivered_at') then
    alter table event_awards rename column delivered_at to paid_at;
  end if;
end $$;

alter table event_awards drop constraint if exists event_awards_status_check;

update event_awards set status = 'agendado' where status = 'comprado';
update event_awards set status = 'pago' where status = 'entregue';

alter table event_awards add constraint event_awards_status_check check (status in ('pendente', 'agendado', 'pago'));

create index if not exists idx_event_awards_streamer on event_awards(streamer_id) where streamer_id is not null;

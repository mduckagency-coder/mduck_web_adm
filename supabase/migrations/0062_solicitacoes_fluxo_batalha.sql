-- ============================================================================
-- Solicitacoes: notificacao geral ao chegar pedido novo, exclusao pelo adm,
-- mensagem de aprovacao, e fluxo estendido de Batalha Oficial (busca de
-- oponente -> confirmacao -> conclusao, com historico).
-- Rode manualmente no SQL Editor do Supabase. Aditivo/idempotente.
-- ============================================================================

alter table calendar_requests add column if not exists approval_message text;
alter table calendar_requests add column if not exists battle_opponent_name text;
alter table calendar_requests add column if not exists battle_score text;

comment on column calendar_requests.approval_message is 'Mensagem opcional da agencia pro streamer ao aprovar';
comment on column calendar_requests.battle_opponent_name is 'Preenchido quando o oponente da batalha oficial e encontrado/confirmado';
comment on column calendar_requests.battle_score is 'Pontuacao/resultado final, preenchido opcionalmente ao concluir a batalha';

-- Novo status: buscando_oponente e oponente_confirmado ficam entre
-- aguardando_analise e concluida, exclusivos de batalha_oficial (evento
-- continua indo direto de aguardando_analise pra aprovada).
alter table calendar_requests drop constraint if exists calendar_requests_status_check;
alter table calendar_requests add constraint calendar_requests_status_check
  check (status in ('aguardando_analise', 'buscando_oponente', 'oponente_confirmado', 'aprovada', 'rejeitada', 'cancelada', 'concluida'));

create table if not exists calendar_request_status_history (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references calendar_requests(id) on delete cascade,
  status text not null,
  note text,
  changed_by uuid references managers(id),
  changed_at timestamptz not null default now()
);
create index if not exists idx_calendar_request_status_history_request on calendar_request_status_history(request_id, changed_at);

alter table calendar_request_status_history enable row level security;
drop policy if exists "calendar_request_status_history_agency" on calendar_request_status_history;
create policy "calendar_request_status_history_agency" on calendar_request_status_history
  for all using (
    exists (
      select 1 from calendar_requests r
      where r.id = calendar_request_status_history.request_id
      and r.agency_id = (select agency_id from managers where id = auth.uid())
    )
  )
  with check (
    exists (
      select 1 from calendar_requests r
      where r.id = calendar_request_status_history.request_id
      and r.agency_id = (select agency_id from managers where id = auth.uid())
    )
  );

drop policy if exists "calendar_request_status_history_streamer_select" on calendar_request_status_history;
create policy "calendar_request_status_history_streamer_select" on calendar_request_status_history
  for select using (
    exists (
      select 1 from calendar_requests r
      where r.id = calendar_request_status_history.request_id
      and r.requested_by_streamer_id in (select id from profiles where auth_user_id = auth.uid())
    )
  );

-- ============================================================================
-- Notificacao geral (dono/coordenador) quando um streamer envia uma
-- solicitacao nova -- roda via trigger porque o insert pode vir direto do
-- app do streamer, sem passar pelo admin.
-- ============================================================================
create or replace function notify_managers_new_calendar_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into manager_notifications (manager_id, subject, message)
  select m.id,
         case when new.request_type = 'batalha_oficial' then 'Nova solicitação de Batalha Oficial' else 'Nova solicitação de Evento' end,
         coalesce((select display_name from profiles where id = new.requested_by_streamer_id), 'Um streamer')
           || ' enviou uma nova solicitação e está aguardando análise.'
  from managers m
  where m.agency_id = new.agency_id
    and (m.financial_role = 'dono' or m.role = 'coordenador');
  return new;
end;
$$;

drop trigger if exists trg_notify_new_calendar_request on calendar_requests;
create trigger trg_notify_new_calendar_request
  after insert on calendar_requests
  for each row
  execute function notify_managers_new_calendar_request();

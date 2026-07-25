-- ============================================================================
-- Cronograma (Eventos > Cronograma): cada atividade agora tem inicio e fim
-- (data+hora), um "tipo de evento" (reaproveita event_categories do modulo
-- Calendario), um ou mais streamers vinculados, uma ou mais premiacoes
-- (escritas a mao ou selecionadas entre as ja cadastradas na aba
-- Premiacoes deste evento) e a opcao de tambem aparecer no Calendario geral
-- (Agenda da Agencia). Quando vinculada a um streamer, a atividade passa a
-- aparecer automaticamente na Agenda dos Streamers (calendario individual,
-- ja mostra qualquer evento com participante streamer) e fica disponivel
-- pro app do streamer ler -- feito espelhando a atividade como um
-- calendar_events real (mesma fonte de dados do modulo Calendario), em vez
-- de duplicar um sistema paralelo. calendar_event_id guarda o vinculo com
-- esse espelho.
--
-- Colunas notified_1d_at/notified_1h_at marcam quando o aviso de 1 dia / 1
-- hora antes ja foi enviado aos gestores. A funcao que envia
-- (notify_upcoming_event_schedule) esta pronta, mas so dispara sozinha se
-- uma tarefa agendada (pg_cron) for configurada -- ver instrucoes no final
-- deste arquivo.
-- ============================================================================
alter table event_schedule add column if not exists start_at timestamptz;
alter table event_schedule add column if not exists end_at timestamptz;
update event_schedule set start_at = (activity_date + coalesce(activity_time, '00:00:00'::time))::timestamptz where start_at is null;
alter table event_schedule alter column start_at set not null;

alter table event_schedule add column if not exists category_id uuid references event_categories(id);
alter table event_schedule add column if not exists awards jsonb not null default '[]'::jsonb;
alter table event_schedule add column if not exists show_in_agency_calendar boolean not null default false;
alter table event_schedule add column if not exists calendar_event_id uuid references calendar_events(id) on delete set null;
alter table event_schedule add column if not exists notified_1d_at timestamptz;
alter table event_schedule add column if not exists notified_1h_at timestamptz;

create index if not exists idx_event_schedule_start_at on event_schedule(start_at);

-- Streamers vinculados a uma atividade do cronograma (varios por atividade).
create table if not exists event_schedule_streamers (
  schedule_id uuid not null references event_schedule(id) on delete cascade,
  streamer_id uuid not null references profiles(id) on delete cascade,
  primary key (schedule_id, streamer_id)
);
create index if not exists idx_event_schedule_streamers_streamer on event_schedule_streamers(streamer_id);

alter table event_schedule_streamers enable row level security;
drop policy if exists "event_schedule_streamers_agency" on event_schedule_streamers;
create policy "event_schedule_streamers_agency" on event_schedule_streamers for all using (
  exists (
    select 1 from event_schedule s
    join agency_events e on e.id = s.event_id
    where s.id = event_schedule_streamers.schedule_id
    and e.agency_id = (select agency_id from managers where id = auth.uid())
  )
) with check (
  exists (
    select 1 from event_schedule s
    join agency_events e on e.id = s.event_id
    where s.id = event_schedule_streamers.schedule_id
    and e.agency_id = (select agency_id from managers where id = auth.uid())
  )
);

-- Envia (best effort) uma notificacao aos gestores quando faltar ~1 dia ou
-- ~1 hora para uma atividade comecar. Marca notified_1d_at/notified_1h_at
-- pra nao notificar duas vezes. Notifica o responsavel da atividade
-- (responsible_manager_id); se nao tiver responsavel definido, notifica
-- dono+coordenadores da agencia (mesma regra ja usada em
-- notifyNewEventToAdmins no app).
create or replace function notify_upcoming_event_schedule()
returns void
language plpgsql
security definer
as $$
declare
  r record;
  recipient uuid;
begin
  for r in
    select s.id, s.description, s.responsible_manager_id, e.agency_id
    from event_schedule s
    join agency_events e on e.id = s.event_id
    where s.status not in ('concluido', 'cancelado')
      and s.notified_1d_at is null
      and s.start_at between now() + interval '23 hours 45 minutes' and now() + interval '24 hours 15 minutes'
  loop
    if r.responsible_manager_id is not null then
      insert into manager_notifications (manager_id, subject, message)
      values (r.responsible_manager_id, 'Atividade amanha', 'A atividade "' || r.description || '" comeca em cerca de 1 dia.');
    else
      for recipient in select id from managers where agency_id = r.agency_id and (financial_role = 'dono' or role = 'coordenador')
      loop
        insert into manager_notifications (manager_id, subject, message)
        values (recipient, 'Atividade amanha', 'A atividade "' || r.description || '" comeca em cerca de 1 dia.');
      end loop;
    end if;
    update event_schedule set notified_1d_at = now() where id = r.id;
  end loop;

  for r in
    select s.id, s.description, s.responsible_manager_id, e.agency_id
    from event_schedule s
    join agency_events e on e.id = s.event_id
    where s.status not in ('concluido', 'cancelado')
      and s.notified_1h_at is null
      and s.start_at between now() + interval '45 minutes' and now() + interval '75 minutes'
  loop
    if r.responsible_manager_id is not null then
      insert into manager_notifications (manager_id, subject, message)
      values (r.responsible_manager_id, 'Atividade em 1 hora', 'A atividade "' || r.description || '" comeca em cerca de 1 hora.');
    else
      for recipient in select id from managers where agency_id = r.agency_id and (financial_role = 'dono' or role = 'coordenador')
      loop
        insert into manager_notifications (manager_id, subject, message)
        values (recipient, 'Atividade em 1 hora', 'A atividade "' || r.description || '" comeca em cerca de 1 hora.');
      end loop;
    end if;
    update event_schedule set notified_1h_at = now() where id = r.id;
  end loop;
end;
$$;

-- Para ativar o envio automatico (precisa da extensao pg_cron habilitada em
-- Database > Extensions no painel do Supabase), rode no SQL Editor:
--
--   select cron.schedule('notify_upcoming_event_schedule', '*/15 * * * *', $$select notify_upcoming_event_schedule()$$);
--
-- Sem isso, a funcao existe mas so roda se for chamada manualmente:
--   select notify_upcoming_event_schedule();

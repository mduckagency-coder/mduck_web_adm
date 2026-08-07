-- ============================================================================
-- Calendario: separa "pra quem e o evento" (scope) de "onde ele aparece"
-- (Agenda da Agencia x aplicativo do streamer) -- antes disso, todo evento
-- scope='agencia' aparecia no app e todo scope='streamer' nao aparecia na
-- Agenda da Agencia, sem opcao de mudar. Rode manualmente no SQL Editor do
-- Supabase. Aditivo/idempotente.
-- ============================================================================

alter table calendar_events add column if not exists show_in_agency_calendar boolean not null default true;
alter table calendar_events add column if not exists show_in_app boolean not null default false;
alter table calendar_events add column if not exists color_override text;

comment on column calendar_events.show_in_agency_calendar is 'Aparece na Agenda da Agencia (Home Central)';
comment on column calendar_events.show_in_app is 'Aparece no calendario do aplicativo do streamer';
comment on column calendar_events.color_override is 'Cor especifica do evento (ex: Campanhas TikTok com varias no mesmo mes), sobrepoe a cor da categoria';

-- Backfill: preserva o comportamento antigo (implicito) dos eventos ja
-- existentes antes dessas colunas terem default -- sem isso, "eventos teste"
-- criados antes desta migration ficariam com show_in_app=false (o default
-- novo) mesmo os que eram scope='streamer' (que antes ja apareciam no app).
update calendar_events set show_in_agency_calendar = true, show_in_app = true where scope = 'agencia';
update calendar_events set show_in_agency_calendar = false, show_in_app = true where scope = 'streamer';

-- Categorias novas, exclusivas do Calendario APP (Streamers) -- a tela usa
-- so estas 5 (ver appCalendarCategoryKeys em calendar_colors.dart), as
-- antigas ("Batalha Oficial", "Treinamento Gamer" etc.) continuam existindo
-- para eventos ja criados, so nao aparecem mais no dropdown dessa tela.
insert into event_categories (agency_id, key, name, color, scope, order_index, is_active)
select a.agency_id, c.key, c.name, c.color, c.scope, 900 + c.ord, true
from (select distinct agency_id from managers) a
cross join (values
  ('evento_individual', 'Evento Individual', '#7A0BD4', 'streamer', 1),
  ('acompanhamento_streamer', 'Acompanhamento Streamer', '#2E86DE', 'streamer', 2),
  ('evento_agencia_app', 'Eventos da Agência', '#27AE60', 'ambos', 3),
  ('campanha_tiktok_app', 'Campanhas TikTok', '#F1C40F', 'streamer', 4),
  ('treinamento_agencia_app', 'Treinamentos Agência', '#E67E22', 'ambos', 5)
) as c(key, name, color, scope, ord)
where not exists (
  select 1 from event_categories e where e.agency_id = a.agency_id and e.key = c.key
);

-- ============================================================================
-- RLS: leitura do app filtrada por show_in_app (a policy de gestor
-- existente em 0001_calendario.sql cobre o admin; esta e so leitura do
-- streamer logado, restrita ao que deve mesmo aparecer no app dele).
-- ============================================================================
drop policy if exists "calendar_events_streamer_select" on calendar_events;
create policy "calendar_events_streamer_select" on calendar_events
  for select using (
    show_in_app = true
    and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

drop policy if exists "calendar_event_participants_streamer_select" on calendar_event_participants;
create policy "calendar_event_participants_streamer_select" on calendar_event_participants
  for select using (
    exists (
      select 1 from calendar_events e
      where e.id = calendar_event_participants.event_id
      and e.show_in_app = true
      and e.agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
    )
  );

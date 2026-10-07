-- ============================================================================
-- Novidades Home (Operacoes APP > Novidades Home): mural de comunicados da
-- agencia que o streamer abre pelo pergaminho na Home do app.
--
-- NAO e o sino: streamer_notifications continua sendo das notificacoes
-- pessoais/acionaveis. Novidade nenhuma gera notificacao no sino.
--
-- Publico (mesmo formato das Missoes APP, target_type + target_id):
--   all         todos os streamers da agencia
--   group       um grupo (group_members ou profiles.group_id)
--   individual  um streamer especifico (target_id = profiles.id)
--
-- Historico: nada e apagado automaticamente. O app so pede as mais recentes
-- (app_news_for_me com limite); o painel mostra tudo, organizado por mes.
--
-- Lida/nao lida: agency_news_reads (uma linha por novidade x streamer, com
-- read_at) -- mesmo conceito do read_at das notificacoes, separado porque uma
-- novidade e uma so pra muitos streamers.
--
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

create table if not exists agency_news (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  title text not null,
  body text not null,
  image_url text,
  link_url text,
  link_label text,
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true,
  target_type text not null default 'all' check (target_type in ('all', 'group', 'individual')),
  target_id uuid,
  created_by uuid references managers(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_agency_news_agency_published on agency_news(agency_id, published_at desc);

comment on table agency_news is 'Novidades da agencia mostradas no pergaminho da Home do app. target_type: all | group (target_id = groups.id) | individual (target_id = profiles.id). Historico permanente; o app mostra so as mais recentes.';

create table if not exists agency_news_reads (
  news_id uuid not null references agency_news(id) on delete cascade,
  streamer_id uuid not null references profiles(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (news_id, streamer_id)
);

-- ============================================================================
-- RLS
-- ============================================================================
alter table agency_news enable row level security;
alter table agency_news_reads enable row level security;

drop policy if exists "agency_news_agency" on agency_news;
create policy "agency_news_agency" on agency_news
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

-- Gestor ve quem ja leu (contador "lida por X" no painel).
drop policy if exists "agency_news_reads_agency_select" on agency_news_reads;
create policy "agency_news_reads_agency_select" on agency_news_reads
  for select using (
    news_id in (select id from agency_news where agency_id = (select agency_id from managers where id = auth.uid()))
  );

-- O streamer le/grava so as proprias leituras (o app usa as funcoes abaixo).
drop policy if exists "agency_news_reads_streamer" on agency_news_reads;
create policy "agency_news_reads_streamer" on agency_news_reads
  for all using (streamer_id in (select id from profiles where auth_user_id = auth.uid()))
  with check (streamer_id in (select id from profiles where auth_user_id = auth.uid()));

-- Storage: imagens das novidades vao no bucket publico island_media (prefixo
-- "news_"), que ja existe (0067).

-- ============================================================================
-- Funcoes usadas pelo app (security definer: resolvem o publico sem o app
-- precisar ler grupos/perfis de outros streamers).
-- ============================================================================

-- Novidades visiveis pro streamer logado agora, da mais recente pra mais
-- antiga, com o estado de leitura. p_limit controla quantas (o app pede 15 e
-- "Ver anteriores" pede mais).
create or replace function app_news_for_me(p_limit int default 15)
returns table (
  id uuid,
  title text,
  body text,
  image_url text,
  link_url text,
  link_label text,
  published_at timestamptz,
  is_read boolean
)
language sql stable security definer
set search_path = public
as $$
  with me as (
    select p.id, p.agency_id, p.group_id
    from profiles p
    where p.auth_user_id = auth.uid()
    limit 1
  )
  select
    n.id, n.title, n.body, n.image_url, n.link_url, n.link_label, n.published_at,
    exists (select 1 from agency_news_reads r where r.news_id = n.id and r.streamer_id = me.id) as is_read
  from agency_news n
  join me on n.agency_id = me.agency_id
  where n.is_active
    and n.published_at <= now()
    and (n.expires_at is null or n.expires_at > now())
    and (
      n.target_type = 'all'
      or (n.target_type = 'individual' and n.target_id = me.id)
      or (n.target_type = 'group' and (
            n.target_id = me.group_id
            or exists (select 1 from group_members gm where gm.group_id = n.target_id and gm.streamer_id = me.id)
          ))
    )
  order by n.published_at desc
  limit greatest(1, least(coalesce(p_limit, 15), 200));
$$;

-- Marca como lidas (so novidades da agencia do proprio streamer).
create or replace function app_mark_news_read(p_news_ids uuid[])
returns void
language sql volatile security definer
set search_path = public
as $$
  insert into agency_news_reads (news_id, streamer_id)
  select n.id, p.id
  from agency_news n
  join profiles p on p.auth_user_id = auth.uid() and p.agency_id = n.agency_id
  where n.id = any(p_news_ids)
  on conflict (news_id, streamer_id) do nothing;
$$;

grant execute on function app_news_for_me(int) to authenticated;
grant execute on function app_mark_news_read(uuid[]) to authenticated;

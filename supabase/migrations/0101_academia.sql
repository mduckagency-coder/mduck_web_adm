-- ============================================================================
-- ACADEMIA MDUCK (substitui MAX Aulas)
--
-- Tudo editavel pelo painel, sem codigo:
--   academy_categories  categorias (flexiveis: novos nichos = nova linha)
--   academy_series      aulas em serie (sequencia, nao "trilha" visual)
--   academy_lessons     aulas; o conteudo e uma lista de BLOCOS em jsonb
--                       (texto, "Como o TikTok funciona", Dica MDuck, imagem,
--                       YouTube, passos, toque para descobrir, simulacao de
--                       LIVE, quiz, checklist, desafio...)
--   academy_progress    nao iniciado / em andamento / concluido
--   academy_access_requests + academy_access_grants   solicitacoes/liberacoes
--
-- O app le tudo por funcoes do servidor (academy_catalog / academy_lesson),
-- que ja aplicam publicacao, bloqueio, liberacoes e o "Visualizar como" do
-- painel. Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabelas
-- ----------------------------------------------------------------------------
create table if not exists academy_categories (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  slug text not null,
  title text not null,
  subtitle text,
  emoji text,
  theme text not null default 'fundamentos',   -- identidade visual no app
  audience text,                                -- perfil que ve essa categoria primeiro (games, musica, batalhas, conversa)
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (agency_id, slug)
);

create table if not exists academy_series (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  slug text not null,
  title text not null,
  subtitle text,
  emoji text,
  category_id uuid references academy_categories(id) on delete set null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (agency_id, slug)
);

create table if not exists academy_lessons (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  slug text,
  category_id uuid references academy_categories(id) on delete set null,
  subcategory text,
  title text not null,
  subtitle text,
  summary text,
  audience text[] not null default array['todos'],          -- todos, games, musica, batalhas, conversa
  level text not null default 'iniciante' check (level in ('iniciante', 'intermediario', 'avancado')),
  thumbnail_url text,
  cover_url text,
  blocks jsonb not null default '[]'::jsonb,
  availability text not null default 'bloqueado'
    check (availability in ('disponivel', 'bloqueado', 'solicitacao', 'em_breve')),
  status text not null default 'rascunho' check (status in ('rascunho', 'revisao', 'publicado')),
  is_active boolean not null default true,
  featured boolean not null default false,       -- "Em destaque" na home
  recommended boolean not null default false,    -- peso extra em "Recomendado para voce"
  start_here boolean not null default false,     -- "Nao sabe por onde comecar?"
  series_id uuid references academy_series(id) on delete set null,
  series_order int,
  sort_order int not null default 0,
  duration_min int,
  tags text[] not null default '{}',
  -- controle de acesso alem da disponibilidade
  access_mode text not null default 'todos' check (access_mode in ('todos', 'streamers', 'audiencias')),
  allowed_streamer_ids uuid[] not null default '{}',
  allowed_audiences text[] not null default '{}',
  -- fontes (o TikTok muda: nada de informacao antiga parecendo eterna)
  sources jsonb not null default '[]'::jsonb,    -- [{title, url, consulted_at}]
  reviewed_at date,
  info_status text not null default 'revisar' check (info_status in ('atual', 'revisar', 'desatualizado')),
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_academy_lessons_agency on academy_lessons(agency_id, status, is_active);
create unique index if not exists idx_academy_lessons_slug on academy_lessons(agency_id, slug) where slug is not null;

create table if not exists academy_progress (
  profile_id uuid not null references profiles(id) on delete cascade,
  lesson_id uuid not null references academy_lessons(id) on delete cascade,
  status text not null default 'em_andamento' check (status in ('em_andamento', 'concluido')),
  progress numeric not null default 0,
  open_count int not null default 0,
  quiz jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (profile_id, lesson_id)
);

create table if not exists academy_access_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  lesson_id uuid not null references academy_lessons(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'pendente' check (status in ('pendente', 'aprovado', 'recusado')),
  note text,
  handled_by uuid,
  handled_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists idx_academy_requests_agency on academy_access_requests(agency_id, status, created_at desc);

create table if not exists academy_access_grants (
  lesson_id uuid not null references academy_lessons(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  granted_by uuid,
  created_at timestamptz not null default now(),
  primary key (lesson_id, profile_id)
);

-- ----------------------------------------------------------------------------
-- RLS: o painel (gestores) edita tudo da agencia; o app so usa as funcoes
-- ----------------------------------------------------------------------------
alter table academy_categories enable row level security;
alter table academy_series enable row level security;
alter table academy_lessons enable row level security;
alter table academy_progress enable row level security;
alter table academy_access_requests enable row level security;
alter table academy_access_grants enable row level security;

drop policy if exists "academy_categories_managers" on academy_categories;
create policy "academy_categories_managers" on academy_categories for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "academy_series_managers" on academy_series;
create policy "academy_series_managers" on academy_series for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "academy_lessons_managers" on academy_lessons;
create policy "academy_lessons_managers" on academy_lessons for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "academy_requests_managers" on academy_access_requests;
create policy "academy_requests_managers" on academy_access_requests for all
  using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "academy_grants_managers" on academy_access_grants;
create policy "academy_grants_managers" on academy_access_grants for all
  using (exists (select 1 from academy_lessons l join managers m on m.agency_id = l.agency_id
                 where l.id = academy_access_grants.lesson_id and m.id = auth.uid()))
  with check (exists (select 1 from academy_lessons l join managers m on m.agency_id = l.agency_id
                      where l.id = academy_access_grants.lesson_id and m.id = auth.uid()));

drop policy if exists "academy_progress_managers_read" on academy_progress;
create policy "academy_progress_managers_read" on academy_progress for select
  using (exists (select 1 from profiles p join managers m on m.agency_id = p.agency_id
                 where p.id = academy_progress.profile_id and m.id = auth.uid()));

-- imagens das aulas (thumbnail, capa, blocos de imagem/GIF)
insert into storage.buckets (id, name, public) values ('academy', 'academy', true)
on conflict (id) do nothing;
drop policy if exists "academy_storage_managers_write" on storage.objects;
create policy "academy_storage_managers_write" on storage.objects for insert to authenticated
  with check (bucket_id = 'academy' and exists (select 1 from managers where id = auth.uid()));
drop policy if exists "academy_storage_managers_delete" on storage.objects;
create policy "academy_storage_managers_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'academy' and exists (select 1 from managers where id = auth.uid()));

-- ----------------------------------------------------------------------------
-- Perfil do streamer -> publico da Academia (so ordena/recomenda, nao bloqueia)
-- ----------------------------------------------------------------------------
create or replace function academy_audience_of(p_profile uuid)
returns text
language sql stable security definer
set search_path = public
as $$
  select case
    when c.icon_key = 'gamer' or c.name ilike '%game%' or c.name ilike '%jog%' then 'games'
    when c.icon_key = 'musico' or c.name ilike '%m_sic%' then 'musica'
    when c.icon_key = 'batalha' or c.name ilike '%batalh%' then 'batalhas'
    when c.id is not null then 'conversa'
    else 'todos' end
  from profiles p left join streamer_categories c on c.id = p.category_id
  where p.id = p_profile;
$$;

-- ----------------------------------------------------------------------------
-- Quem esta olhando: streamer (o proprio perfil) ou gestor (com "Visualizar
-- como" opcional: um streamer especifico ou so um perfil de publico)
-- ----------------------------------------------------------------------------
create or replace function academy_viewer(p_profile uuid default null, p_audience text default null)
returns table (agency_id uuid, profile_id uuid, audience text, is_manager boolean, admin_view boolean)
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_mgr_agency uuid;
  v_profile uuid;
  v_agency uuid;
begin
  select m.agency_id into v_mgr_agency from managers m where m.id = auth.uid();
  if v_mgr_agency is not null then
    if p_profile is not null then
      select p.id into v_profile from profiles p where p.id = p_profile and p.agency_id = v_mgr_agency;
    end if;
    return query select v_mgr_agency, v_profile,
      coalesce(nullif(p_audience, ''), case when v_profile is not null then academy_audience_of(v_profile) else 'todos' end),
      true,
      (v_profile is null and coalesce(p_audience, '') = '');
    return;
  end if;
  select p.id, p.agency_id into v_profile, v_agency from profiles p where p.auth_user_id = auth.uid() limit 1;
  if v_profile is null then raise exception 'perfil nao encontrado'; end if;
  return query select v_agency, v_profile, academy_audience_of(v_profile), false, false;
end;
$$;

-- acesso de uma aula pra quem esta olhando: open | locked | soon
create or replace function academy_access(l academy_lessons, v_profile uuid, v_audience text, v_admin boolean)
returns text
language sql stable security definer
set search_path = public
as $$
  select case
    when v_admin then 'open'
    when l.availability = 'em_breve' then 'soon'
    when v_profile is not null and exists (select 1 from academy_access_grants g where g.lesson_id = l.id and g.profile_id = v_profile) then 'open'
    when l.availability in ('bloqueado', 'solicitacao') then 'locked'
    when l.access_mode = 'streamers' and not (v_profile = any(l.allowed_streamer_ids)) then 'locked'
    when l.access_mode = 'audiencias' and not (v_audience = any(l.allowed_audiences)) then 'locked'
    else 'open' end;
$$;

-- ----------------------------------------------------------------------------
-- Catalogo (home, categorias, busca): tudo menos o conteudo das aulas
-- ----------------------------------------------------------------------------
create or replace function academy_catalog(p_profile uuid default null, p_audience text default null)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v record;
begin
  select * into v from academy_viewer(p_profile, p_audience);
  return jsonb_build_object(
    'audience', v.audience,
    'is_manager', v.is_manager,
    'admin_view', v.admin_view,
    'has_profile', v.profile_id is not null,
    'categories', coalesce((
      select jsonb_agg(to_jsonb(c) - 'agency_id' - 'created_at' order by c.sort_order, c.title)
      from academy_categories c where c.agency_id = v.agency_id and c.is_active), '[]'::jsonb),
    'series', coalesce((
      select jsonb_agg(to_jsonb(s) - 'agency_id' - 'created_at' order by s.sort_order, s.title)
      from academy_series s where s.agency_id = v.agency_id and s.is_active), '[]'::jsonb),
    'lessons', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'slug', l.slug, 'category_id', l.category_id, 'subcategory', l.subcategory,
        'title', l.title, 'subtitle', l.subtitle, 'summary', l.summary, 'audience', to_jsonb(l.audience),
        'level', l.level, 'thumbnail_url', l.thumbnail_url, 'cover_url', l.cover_url,
        'featured', l.featured, 'recommended', l.recommended, 'start_here', l.start_here,
        'series_id', l.series_id, 'series_order', l.series_order, 'sort_order', l.sort_order,
        'duration_min', l.duration_min, 'tags', to_jsonb(l.tags), 'availability', l.availability,
        'status', l.status,
        'access', academy_access(l, v.profile_id, v.audience, v.admin_view),
        'block_types', (select coalesce(jsonb_agg(distinct b->>'type'), '[]'::jsonb) from jsonb_array_elements(l.blocks) b),
        'progress_status', pr.status, 'progress', pr.progress, 'last_opened_at', pr.updated_at,
        'request_status', rq.status
      ) order by l.sort_order, l.created_at)
      from academy_lessons l
      left join academy_progress pr on pr.lesson_id = l.id and pr.profile_id = v.profile_id
      left join lateral (select r.status from academy_access_requests r
                         where r.lesson_id = l.id and r.profile_id = v.profile_id
                         order by r.created_at desc limit 1) rq on true
      where l.agency_id = v.agency_id and l.is_active
        and (v.admin_view or l.status = 'publicado')), '[]'::jsonb)
  );
end;
$$;
grant execute on function academy_catalog(uuid, text) to authenticated;

-- Uma aula completa (blocos so vao se a pessoa tiver acesso)
create or replace function academy_lesson(p_lesson uuid, p_profile uuid default null, p_audience text default null)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v record;
  l academy_lessons;
  v_access text;
begin
  select * into v from academy_viewer(p_profile, p_audience);
  select * into l from academy_lessons x where x.id = p_lesson and x.agency_id = v.agency_id and x.is_active;
  if l.id is null or (not v.admin_view and l.status <> 'publicado') then return null; end if;
  v_access := academy_access(l, v.profile_id, v.audience, v.admin_view);
  return (to_jsonb(l) - 'agency_id' - 'allowed_streamer_ids' - 'created_by'
           - case when v_access = 'open' then 'xxx' else 'blocks' end)
    || jsonb_build_object(
      'access', v_access,
      'quiz', (select pr.quiz from academy_progress pr where pr.lesson_id = l.id and pr.profile_id = v.profile_id),
      'progress_status', (select pr.status from academy_progress pr where pr.lesson_id = l.id and pr.profile_id = v.profile_id),
      'request_status', (select r.status from academy_access_requests r where r.lesson_id = l.id and r.profile_id = v.profile_id order by r.created_at desc limit 1));
end;
$$;
grant execute on function academy_lesson(uuid, uuid, text) to authenticated;

-- Progresso do proprio streamer ('open' = abriu a aula)
create or replace function academy_track(p_lesson uuid, p_event text, p_progress numeric default null, p_quiz jsonb default null)
returns void
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_profile uuid;
begin
  select id into v_profile from profiles where auth_user_id = auth.uid() limit 1;
  if v_profile is null then return; end if; -- gestor visualizando: nao grava
  insert into academy_progress (profile_id, lesson_id, status, progress, open_count, quiz, completed_at)
  values (v_profile, p_lesson,
          case when p_event = 'complete' then 'concluido' else 'em_andamento' end,
          case when p_event = 'complete' then 1 else coalesce(p_progress, 0) end,
          case when p_event = 'open' then 1 else 0 end,
          coalesce(p_quiz, '{}'::jsonb),
          case when p_event = 'complete' then now() end)
  on conflict (profile_id, lesson_id) do update set
    status = case when academy_progress.status = 'concluido' or p_event = 'complete' then 'concluido' else 'em_andamento' end,
    progress = case when p_event = 'complete' then 1 else greatest(academy_progress.progress, coalesce(p_progress, 0)) end,
    open_count = academy_progress.open_count + case when p_event = 'open' then 1 else 0 end,
    quiz = academy_progress.quiz || coalesce(p_quiz, '{}'::jsonb),
    completed_at = coalesce(academy_progress.completed_at, case when p_event = 'complete' then now() end),
    updated_at = now();
end;
$$;
grant execute on function academy_track(uuid, text, numeric, jsonb) to authenticated;

-- Solicitar acesso a uma aula bloqueada
create or replace function academy_request_access(p_lesson uuid)
returns text
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_profile uuid;
  v_agency uuid;
begin
  select id, agency_id into v_profile, v_agency from profiles where auth_user_id = auth.uid() limit 1;
  if v_profile is null then raise exception 'perfil nao encontrado'; end if;
  if not exists (select 1 from academy_lessons where id = p_lesson and agency_id = v_agency) then raise exception 'aula nao encontrada'; end if;
  if exists (select 1 from academy_access_requests where lesson_id = p_lesson and profile_id = v_profile and status = 'pendente') then
    return 'pendente';
  end if;
  insert into academy_access_requests (agency_id, lesson_id, profile_id) values (v_agency, p_lesson, v_profile);
  return 'pendente';
end;
$$;
grant execute on function academy_request_access(uuid) to authenticated;

-- Painel: aprovar/recusar (aprovar ja libera a aula pro streamer)
create or replace function academy_handle_request(p_request uuid, p_status text, p_note text default null)
returns void
language plpgsql volatile security definer
set search_path = public
as $$
declare
  r academy_access_requests;
begin
  select * into r from academy_access_requests x
  where x.id = p_request and x.agency_id = (select agency_id from managers where id = auth.uid());
  if r.id is null then raise exception 'solicitacao nao encontrada'; end if;
  update academy_access_requests set status = p_status, note = nullif(trim(coalesce(p_note, '')), ''),
         handled_by = auth.uid(), handled_at = now() where id = r.id;
  if p_status = 'aprovado' then
    insert into academy_access_grants (lesson_id, profile_id, granted_by) values (r.lesson_id, r.profile_id, auth.uid())
    on conflict do nothing;
  elsif p_status = 'recusado' then
    delete from academy_access_grants where lesson_id = r.lesson_id and profile_id = r.profile_id;
  end if;
end;
$$;
grant execute on function academy_handle_request(uuid, text, text) to authenticated;

-- Painel: indicadores
create or replace function academy_metrics()
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  v_agency uuid := (select agency_id from managers where id = auth.uid());
begin
  if v_agency is null then raise exception 'apenas gestores'; end if;
  return jsonb_build_object(
    'lessons', coalesce((
      select jsonb_agg(x order by x.views desc) from (
        select l.id, l.title, c.title as category,
               coalesce(sum(p.open_count), 0)::int as views,
               count(p.*)::int as learners,
               count(p.*) filter (where p.status = 'concluido')::int as completed,
               (select count(*) from academy_access_requests r where r.lesson_id = l.id)::int as requests
        from academy_lessons l
        left join academy_categories c on c.id = l.category_id
        left join academy_progress p on p.lesson_id = l.id
        where l.agency_id = v_agency
        group by l.id, l.title, c.title) x), '[]'::jsonb),
    'categories', coalesce((
      select jsonb_agg(x order by x.views desc) from (
        select c.title, coalesce(sum(p.open_count), 0)::int as views,
               count(p.*) filter (where p.status = 'concluido')::int as completed
        from academy_categories c
        left join academy_lessons l on l.category_id = c.id
        left join academy_progress p on p.lesson_id = l.id
        where c.agency_id = v_agency
        group by c.title) x), '[]'::jsonb),
    'streamers', coalesce((
      select jsonb_agg(x order by x.views desc) from (
        select pf.display_name, pf.tiktok_username, coalesce(sum(p.open_count), 0)::int as views,
               count(*) filter (where p.status = 'concluido')::int as completed
        from academy_progress p join profiles pf on pf.id = p.profile_id
        where pf.agency_id = v_agency
        group by pf.display_name, pf.tiktok_username
        order by 3 desc limit 30) x), '[]'::jsonb)
  );
end;
$$;
grant execute on function academy_metrics() to authenticated;

notify pgrst, 'reload schema';

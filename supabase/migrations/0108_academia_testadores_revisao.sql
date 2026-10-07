-- ============================================================================
-- Academia: testadores de aulas "Em revisao"
-- Uma aula em revisao aparece (aberta) tambem para quem estiver em
-- "Liberacoes manuais" da aula no painel. Os demais streamers nao veem.
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

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
        and (v.admin_view or l.status = 'publicado'
             or (l.status = 'revisao' and v.profile_id is not null and exists (
               select 1 from academy_access_grants g where g.lesson_id = l.id and g.profile_id = v.profile_id)))), '[]'::jsonb)
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
  if l.id is null or (not v.admin_view and l.status <> 'publicado'
      and not (l.status = 'revisao' and v.profile_id is not null and exists (
        select 1 from academy_access_grants g where g.lesson_id = l.id and g.profile_id = v.profile_id))) then return null; end if;
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

-- Libera a Aula 01 para a conta de teste @gidreams_
insert into academy_access_grants (lesson_id, profile_id)
select l.id, p.id from academy_lessons l
join profiles p on p.agency_id = l.agency_id and lower(ltrim(p.tiktok_username, '@')) = 'gidreams_'
where l.slug = 'aula-01-perfil-liga-galeria'
on conflict do nothing;

notify pgrst, 'reload schema';

select p.tiktok_username as testador, l.title
from academy_access_grants g join profiles p on p.id = g.profile_id join academy_lessons l on l.id = g.lesson_id
where l.slug = 'aula-01-perfil-liga-galeria';

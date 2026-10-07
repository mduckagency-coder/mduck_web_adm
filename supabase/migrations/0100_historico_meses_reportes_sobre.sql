-- ============================================================================
-- 1. Historico de meses (Ranking e Ilha Top no app):
--    o app lia monthly_stats direto e a permissao (RLS) so deixa o streamer
--    ver a propria linha -> meses anteriores apareciam vazios. Agora o app
--    usa funcoes do servidor que devolvem o resultado final da agencia toda,
--    tenha a pessoa login ou nao, inclusive quem ja saiu.
--    monthly_stats passa a guardar a foto e o avatar da ilha com que cada
--    streamer terminou o mes (gravados na virada do mes).
-- 2. Reportes do app: area do app, titulo (sugestoes) e resposta da equipe
--    (aparece pro streamer em "Meus envios").
-- 3. Sobre a MDuck com texto rico: bucket publico app_content (imagens).
-- Rode manualmente no SQL Editor do Supabase. Idempotente.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Historico de meses
-- ----------------------------------------------------------------------------
alter table monthly_stats add column if not exists battles int;
alter table monthly_stats add column if not exists avatar_url text;
alter table monthly_stats add column if not exists island_avatar_id uuid;

-- meses ja fechados sem foto/avatar guardados: usa o atual (melhor informacao
-- disponivel; dali pra frente fica o do fechamento de cada mes)
update monthly_stats m
set avatar_url = coalesce(m.avatar_url, p.avatar_url),
    island_avatar_id = coalesce(m.island_avatar_id, si.avatar_id)
from profiles p
left join lateral (select x.avatar_id from streamer_islands x where x.streamer_id = p.id limit 1) si on true
where p.id = m.streamer_id and (m.avatar_url is null or m.island_avatar_id is null);

create or replace function virar_mes_streamer_stats()
returns int
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_cur text := to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM');
  v_count int;
begin
  -- 1) o mes que esta saindo vai pro historico, com a foto e o avatar da
  --    ilha com que cada streamer terminou o mes
  insert into monthly_stats (streamer_id, period_key, diamonds, hours_live, days_live, battles, avatar_url, island_avatar_id, closed_at)
  select s.streamer_id, s.period_key, coalesce(s.diamonds, 0), coalesce(s.hours_live, 0), coalesce(s.days_live, 0),
         coalesce(s.battles, 0), p.avatar_url, si.avatar_id, now()
  from streamer_stats s
  join profiles p on p.id = s.streamer_id
  left join lateral (select x.avatar_id from streamer_islands x where x.streamer_id = s.streamer_id limit 1) si on true
  where s.period_key is not null and s.period_key < v_cur
  on conflict (streamer_id, period_key) do update
    set avatar_url = coalesce(monthly_stats.avatar_url, excluded.avatar_url),
        island_avatar_id = coalesce(monthly_stats.island_avatar_id, excluded.island_avatar_id),
        battles = coalesce(nullif(monthly_stats.battles, 0), excluded.battles);

  -- 2) zera para o mes atual
  update streamer_stats
  set diamonds = 0, hours_live = 0, days_live = 0, battles = 0,
      period_key = v_cur, updated_at = now()
  where period_key is null or period_key < v_cur;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
grant execute on function virar_mes_streamer_stats() to authenticated;

-- agencia de quem chama (streamer pelo profiles, gestor pelo managers)
create or replace function app_caller_agency()
returns uuid
language sql stable security definer
set search_path = public
as $$
  select coalesce(
    (select agency_id from profiles where auth_user_id = auth.uid() limit 1),
    (select agency_id from managers where id = auth.uid() limit 1));
$$;
grant execute on function app_caller_agency() to authenticated;

-- meses fechados da agencia (mais recente primeiro)
create or replace function app_month_periods()
returns setof text
language sql stable security definer
set search_path = public
as $$
  select distinct m.period_key
  from monthly_stats m join profiles p on p.id = m.streamer_id
  where p.agency_id = app_caller_agency()
  order by m.period_key desc;
$$;
grant execute on function app_month_periods() to authenticated;

-- resultado final de um mes: todos os streamers da agencia com numeros no
-- mes, com a foto e o avatar da ilha do fechamento
create or replace function app_month_board(p_period text)
returns table (
  streamer_id uuid,
  display_name text,
  tiktok_username text,
  avatar_url text,
  category_name text,
  diamonds bigint,
  hours_live numeric,
  days_live int,
  battles int,
  is_active boolean,
  island_avatar jsonb
)
language sql stable security definer
set search_path = public
as $$
  select p.id,
         coalesce(p.display_name, p.tiktok_username, 'Ducker'),
         p.tiktok_username,
         coalesce(m.avatar_url, p.avatar_url),
         c.name,
         coalesce(m.diamonds, 0)::bigint,
         coalesce(m.hours_live, 0)::numeric,
         coalesce(m.days_live, 0)::int,
         coalesce(m.battles, 0)::int,
         coalesce(p.is_active, false),
         case when a.id is null then null else jsonb_build_object(
           'media_url', a.media_url, 'crop_scale', a.crop_scale, 'crop_offset_x', a.crop_offset_x,
           'crop_offset_y', a.crop_offset_y, 'muted', a.muted, 'volume', a.volume,
           'loop_video', a.loop_video, 'display_shape', a.display_shape) end
  from monthly_stats m
  join profiles p on p.id = m.streamer_id
  left join streamer_categories c on c.id = p.category_id
  left join lateral (select x.avatar_id from streamer_islands x where x.streamer_id = p.id limit 1) si on true
  left join island_avatars a on a.id = coalesce(m.island_avatar_id, si.avatar_id)
  where m.period_key = p_period and p.agency_id = app_caller_agency();
$$;
grant execute on function app_month_board(text) to authenticated;

-- ----------------------------------------------------------------------------
-- 2) Reportes do app: area, titulo e resposta da equipe
-- ----------------------------------------------------------------------------
alter table app_reports add column if not exists area text;
alter table app_reports add column if not exists title text;
alter table app_reports add column if not exists reply text;
alter table app_reports add column if not exists replied_at timestamptz;

drop function if exists app_submit_report(text, text, text, text, text);
create or replace function app_submit_report(
  p_type text, p_description text, p_screenshot_path text default null,
  p_app_version text default null, p_platform text default null,
  p_area text default null, p_title text default null)
returns uuid
language plpgsql volatile security definer
set search_path = public
as $$
declare
  p record;
  v_id uuid;
begin
  if coalesce(trim(p_description), '') = '' then raise exception 'descreva o problema'; end if;
  select id, agency_id, display_name, tiktok_username into p from profiles where auth_user_id = auth.uid() limit 1;
  if p.id is null then raise exception 'perfil nao encontrado'; end if;
  insert into app_reports (agency_id, streamer_id, auth_user_id, streamer_name, streamer_username, type, description,
                           screenshot_path, app_version, platform, area, title)
  values (p.agency_id, p.id, auth.uid(), p.display_name, p.tiktok_username, p_type, trim(p_description),
          nullif(p_screenshot_path, ''), p_app_version, p_platform, nullif(trim(p_area), ''), nullif(trim(p_title), ''))
  returning id into v_id;
  return v_id;
end;
$$;
grant execute on function app_submit_report(text, text, text, text, text, text, text) to authenticated;

-- o que o streamer ve em "Meus envios" (sem a anotacao interna da equipe)
create or replace function app_my_reports()
returns table (id uuid, type text, area text, title text, description text, status text,
               reply text, replied_at timestamptz, created_at timestamptz)
language sql stable security definer
set search_path = public
as $$
  select r.id, r.type, r.area, r.title, r.description, r.status, r.reply, r.replied_at, r.created_at
  from app_reports r
  where r.auth_user_id = auth.uid()
  order by r.created_at desc
  limit 100;
$$;
grant execute on function app_my_reports() to authenticated;

-- ----------------------------------------------------------------------------
-- 3) Imagens do "Sobre a MDuck" (texto rico editado no painel)
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('app_content', 'app_content', true)
on conflict (id) do nothing;

drop policy if exists "app_content_managers_write" on storage.objects;
create policy "app_content_managers_write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'app_content' and exists (select 1 from managers where id = auth.uid()));

drop policy if exists "app_content_managers_delete" on storage.objects;
create policy "app_content_managers_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'app_content' and exists (select 1 from managers where id = auth.uid()));

notify pgrst, 'reload schema';

-- ============================================================================
-- Configuracao Animacao APP: dois menus novos -- Carregamento (video que
-- toca assim que o streamer abre o app, tipo splash) e Introducao (video
-- que toca logo em seguida, antes de entrar no app de verdade). Mesmo
-- esquema de janela de horario (fixo/aleatorio) e ativo/inativo ja usado
-- nos fundos da Ilha Top (island_backgrounds) -- uma tabela so, com uma
-- coluna "kind" pra distinguir carregamento de introducao, evita duplicar
-- schema/RLS/logica pros dois.
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

create table if not exists app_splash_media (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  kind text not null check (kind in ('loading', 'intro')),
  label text not null,
  media_url text not null,
  media_type text not null check (media_type in ('video', 'image')),
  start_time time not null default '00:00',
  end_time time not null default '23:59',
  mode text not null default 'fixed' check (mode in ('fixed', 'random')),
  is_active boolean not null default true,
  muted boolean not null default false,
  volume numeric not null default 1,
  loop_video boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_app_splash_media_agency on app_splash_media(agency_id, kind, is_active);

comment on table app_splash_media is 'Videos/imagens de Carregamento (kind=loading, toca assim que o app abre) e Introducao (kind=intro, toca logo em seguida) por agencia. start_time/end_time definem a janela de horario (pode cruzar meia-noite); mode=fixed sempre aparece na janela, mode=random e sorteado entre os que competem pela mesma janela -- igual island_backgrounds.';

alter table app_splash_media enable row level security;

drop policy if exists "app_splash_media_agency" on app_splash_media;
create policy "app_splash_media_agency" on app_splash_media
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "app_splash_media_streamer_select" on app_splash_media;
create policy "app_splash_media_streamer_select" on app_splash_media
  for select using (
    is_active and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

-- ============================================================================
-- Funcao: escolhe a midia certa pra um horario/kind, respeitando
-- fixo/aleatorio -- mesma logica de island_pick_background (migration 0067),
-- reaproveitada aqui pro app nao precisar reimplementar a regra de horario.
-- ============================================================================
create or replace function app_pick_splash_media(p_agency_id uuid, p_kind text, p_at timestamptz default now())
returns app_splash_media
language plpgsql stable
as $$
declare
  v_time time := (p_at at time zone 'America/Sao_Paulo')::time;
  v_row app_splash_media;
begin
  select * into v_row from app_splash_media
  where agency_id = p_agency_id and kind = p_kind and is_active and mode = 'fixed'
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by sort_order
  limit 1;
  if found then return v_row; end if;

  select * into v_row from app_splash_media
  where agency_id = p_agency_id and kind = p_kind and is_active
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by random()
  limit 1;
  if found then return v_row; end if;

  select * into v_row from app_splash_media
  where agency_id = p_agency_id and kind = p_kind and is_active
  order by sort_order
  limit 1;
  return v_row;
end;
$$;

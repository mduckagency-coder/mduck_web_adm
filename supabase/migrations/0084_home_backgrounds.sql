-- ============================================================================
-- Background Home (Configuracao Animacao APP > Background Home): banco de
-- videos de fundo da Home do app (o pato na ilha), cada um com janela de
-- horario e modo fixo/aleatorio -- mesmo esquema de app_splash_media e
-- island_backgrounds.
--
-- Diferenca importante: o sorteio do modo aleatorio e "do dia". Cada
-- streamer recebe UM video por janela de horario por dia; dentro do mesmo
-- dia ele nao fica trocando a cada vez que o app abre. No dia seguinte sai
-- um sorteio novo (pode repetir ou nao).
--
-- Audio de cada video (audio_mode):
--   'video'   -> toca o som do proprio video (com o volume definido)
--   'default' -> video mudo + toca o audio padrao da Home por cima
--   'mute'    -> sem som nenhum
-- O audio padrao fica em app_settings, chave 'home_default_audio'
-- ({"url": "...", "volume": 0..1}).
--
-- Os videos sempre tocam em loop no app (nao ha opcao de desligar).
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

create table if not exists home_backgrounds (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null,
  label text not null,
  media_url text not null,
  media_type text not null default 'video' check (media_type in ('video', 'image')),
  start_time time not null default '00:00',
  end_time time not null default '23:59',
  mode text not null default 'random' check (mode in ('fixed', 'random')),
  audio_mode text not null default 'video' check (audio_mode in ('video', 'default', 'mute')),
  volume numeric not null default 1,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_home_backgrounds_agency on home_backgrounds(agency_id, is_active);

comment on table home_backgrounds is 'Videos de fundo da Home do app. start_time/end_time = janela de horario (pode cruzar meia-noite). mode=fixed sempre aparece na janela (tem prioridade); mode=random e sorteado 1x por dia por streamer entre os aleatorios da janela. audio_mode: video | default (audio padrao de app_settings.home_default_audio) | mute.';

alter table home_backgrounds enable row level security;

drop policy if exists "home_backgrounds_agency" on home_backgrounds;
create policy "home_backgrounds_agency" on home_backgrounds
  for all using (agency_id = (select agency_id from managers where id = auth.uid()))
  with check (agency_id = (select agency_id from managers where id = auth.uid()));

drop policy if exists "home_backgrounds_streamer_select" on home_backgrounds;
create policy "home_backgrounds_streamer_select" on home_backgrounds
  for select using (
    is_active and agency_id = (select agency_id from profiles where auth_user_id = auth.uid())
  );

-- ============================================================================
-- Funcao: escolhe o video de fundo da Home pra um streamer agora.
--   1. fixo dentro da janela atual (o de menor sort_order)
--   2. aleatorio dentro da janela atual -- sorteio estavel no dia: a ordem
--      vem de md5(id + streamer + data), entao o mesmo streamer ve sempre o
--      mesmo video naquela janela durante o dia todo, e outro no dia seguinte
--   3. nada na janela: qualquer ativo, com o mesmo sorteio do dia
-- Horario e data no fuso de Sao Paulo.
-- ============================================================================
create or replace function home_pick_background(p_agency_id uuid, p_streamer_id uuid, p_at timestamptz default now())
returns home_backgrounds
language plpgsql stable
as $$
declare
  v_local timestamp := p_at at time zone 'America/Sao_Paulo';
  v_time time := v_local::time;
  v_day text := to_char(v_local, 'YYYY-MM-DD');
  v_row home_backgrounds;
begin
  select * into v_row from home_backgrounds
  where agency_id = p_agency_id and is_active and mode = 'fixed'
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by sort_order, created_at
  limit 1;
  if found then return v_row; end if;

  select * into v_row from home_backgrounds
  where agency_id = p_agency_id and is_active
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by md5(id::text || coalesce(p_streamer_id::text, '') || v_day)
  limit 1;
  if found then return v_row; end if;

  select * into v_row from home_backgrounds
  where agency_id = p_agency_id and is_active
  order by md5(id::text || coalesce(p_streamer_id::text, '') || v_day)
  limit 1;
  return v_row;
end;
$$;

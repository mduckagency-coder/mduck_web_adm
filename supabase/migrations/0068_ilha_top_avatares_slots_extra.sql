-- ============================================================================
-- Ilha Top - ajustes pedidos apos o primeiro round:
--  1) imagem de referencia (print do video) pro editor de posicoes conseguir
--     mostrar algo estatico mesmo quando o fundo cadastrado e um video;
--  2) slot "top_11_plus" vira uma AREA (retangulo) em vez de um ponto, com
--     tamanho maximo/minimo pros avatares nao ficarem um em cima do outro
--     quando tiver muitos streamers 80k+ fora do top 10;
--  3) avatar ganha elegibilidade (categoria + diamantes minimos), genero e
--     raridade.
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table island_backgrounds add column if not exists preview_image_url text;
comment on column island_backgrounds.preview_image_url is 'Print/screenshot do video, usado so como referencia visual no editor de posicoes do admin (o video real continua sendo servido por media_url no app).';

alter table island_slots add column if not exists area_width numeric;
alter table island_slots add column if not exists area_height numeric;
alter table island_slots add column if not exists min_scale numeric;
comment on column island_slots.area_width is 'Largura (% da imagem, 0-100) da area do slot. So preenchido em slots do tipo area (top_11_plus); nulo = slot de ponto fixo (Top 1..Top 10).';
comment on column island_slots.area_height is 'Altura (% da imagem, 0-100) da area do slot. So preenchido em slots do tipo area (top_11_plus).';
comment on column island_slots.min_scale is 'Menor escala que os avatares podem assumir dentro da area quando ela estiver lotada (o app interpola entre scale e min_scale conforme a quantidade de streamers).';

-- backfill do slot de area pra quem ja rodou a seed anterior (sem essas colunas)
update island_slots
set area_width = 40, area_height = 18, min_scale = 0.55
where slot_key = 'top_11_plus' and area_width is null;

alter table island_avatars add column if not exists min_diamonds int not null default 0;
alter table island_avatars add column if not exists category_ids uuid[];
alter table island_avatars add column if not exists gender text check (gender in ('feminino','masculino'));
alter table island_avatars add column if not exists rarity text not null default 'comum' check (rarity in ('comum','classico','raro','epico','lendario'));
comment on column island_avatars.min_diamonds is 'Diamantes minimos no mes que o streamer precisa ter pra essa opcao de avatar aparecer pra ele escolher no app. 0 = sem restricao por diamantes (alem da elegibilidade geral da ilha).';
comment on column island_avatars.category_ids is 'IDs de streamer_categories que podem escolher esse avatar. Nulo ou vazio = todas as categorias podem escolher.';
comment on column island_avatars.gender is 'feminino ou masculino. Usado pro app filtrar/organizar as opcoes de avatar.';
comment on column island_avatars.rarity is 'comum, classico, raro, epico ou lendario.';

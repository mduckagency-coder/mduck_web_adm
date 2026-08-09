-- ============================================================================
-- Ilha Top: opcoes de exibicao do avatar (pato) -- hoje o app forca todo
-- avatar dentro de um circulo fixo, sem alternativa. Pedido: dar controle
-- pro admin sobre o formato (recorte) e o tamanho de cada avatar, com uma
-- opcao de manter o comportamento atual como padrao.
--
-- display_shape:
--   'circle_border' (default, = comportamento atual) - circulo com anel
--                    visivel, cor definida por border_color.
--   'circle_plain'  - recorte circular, sem anel visivel.
--   'square'        - recorte quadrado.
-- size_mode:
--   'default' (default, = comportamento atual) - tamanho controlado so pela
--             escala do slot (island_slots.scale), como hoje.
--   'percent' - aplica size_percent (100 = tamanho real do arquivo; menor
--               que 100 diminui, maior que 100 aumenta) por cima da escala
--               do slot.
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table island_avatars add column if not exists display_shape text not null default 'circle_border';
alter table island_avatars add column if not exists border_color text not null default '#FFFFFF';
alter table island_avatars add column if not exists size_mode text not null default 'default';
alter table island_avatars add column if not exists size_percent numeric not null default 100;

alter table island_avatars drop constraint if exists island_avatars_display_shape_check;
alter table island_avatars add constraint island_avatars_display_shape_check check (display_shape in ('circle_border', 'circle_plain', 'square'));

alter table island_avatars drop constraint if exists island_avatars_size_mode_check;
alter table island_avatars add constraint island_avatars_size_mode_check check (size_mode in ('default', 'percent'));

comment on column island_avatars.display_shape is 'Formato de recorte do avatar no app: circle_border (padrao, circulo com anel visivel), circle_plain (circulo sem anel visivel) ou square (quadrado).';
comment on column island_avatars.border_color is 'Cor (hex) do anel visivel, usada quando display_shape = circle_border.';
comment on column island_avatars.size_mode is 'default (padrao, tamanho so pela escala do slot) ou percent (aplica size_percent por cima da escala do slot).';
comment on column island_avatars.size_percent is 'Porcentagem do tamanho real do arquivo aplicada quando size_mode = percent. 100 = tamanho real, menor reduz, maior aumenta.';

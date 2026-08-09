-- ============================================================================
-- Ilha Top / MAX Aulas / Inventario - terceiro round de ajustes:
--  1) slot "Top 1 do mes passado" (foto + nome, calculado automaticamente a
--     partir de monthly_stats, so precisa de posicao no editor);
--  2) configuracao de audio (mudo, volume) e loop infinito em todo vídeo
--     gerenciado pelo admin (Ilha Top: fundos e avatares; MAX Aulas);
--  3) corte/enquadramento (zoom + posicao) em cada vídeo/avatar da Ilha Top,
--     calibrado sobre a imagem de referencia (print), pra corrigir video com
--     area maior do que deveria sem precisar reeditar o arquivo original.
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table island_slots add column if not exists is_enabled boolean not null default true;
comment on column island_slots.is_enabled is 'Permite desligar um slot (ex: Top 1 do mes passado) sem perder a posicao ja configurada.';

alter table island_backgrounds add column if not exists muted boolean not null default false;
alter table island_backgrounds add column if not exists volume numeric not null default 1;
alter table island_backgrounds add column if not exists loop_video boolean not null default true;
alter table island_backgrounds add column if not exists crop_scale numeric not null default 1;
alter table island_backgrounds add column if not exists crop_offset_x numeric not null default 0;
alter table island_backgrounds add column if not exists crop_offset_y numeric not null default 0;
comment on column island_backgrounds.muted is 'Se o video deve tocar sem som no app.';
comment on column island_backgrounds.volume is 'Volume (0 a 1) quando nao mudo.';
comment on column island_backgrounds.loop_video is 'Se o video deve tocar em loop infinito. Quando true, o app NAO pode pausar/interromper esse video ao tocar outro video em outra tela (ex: aula do MAX) - precisa de player proprio e isolado.';
comment on column island_backgrounds.crop_scale is 'Zoom aplicado sobre o video/print de referencia (1 = sem zoom). Usado pro admin corrigir video com area maior/menor do que deveria, sem reeditar o arquivo.';
comment on column island_backgrounds.crop_offset_x is 'Deslocamento horizontal do enquadramento, em % (-50 a 50) a partir do centro.';
comment on column island_backgrounds.crop_offset_y is 'Deslocamento vertical do enquadramento, em % (-50 a 50) a partir do centro.';

alter table island_avatars add column if not exists preview_image_url text;
alter table island_avatars add column if not exists muted boolean not null default false;
alter table island_avatars add column if not exists volume numeric not null default 1;
alter table island_avatars add column if not exists loop_video boolean not null default true;
alter table island_avatars add column if not exists crop_scale numeric not null default 1;
alter table island_avatars add column if not exists crop_offset_x numeric not null default 0;
alter table island_avatars add column if not exists crop_offset_y numeric not null default 0;
comment on column island_avatars.preview_image_url is 'Print/frame do video do avatar, usado como referencia visual no corte (crop) do admin.';
comment on column island_avatars.muted is 'Se o video do avatar deve tocar sem som no app.';
comment on column island_avatars.volume is 'Volume (0 a 1) quando nao mudo.';
comment on column island_avatars.loop_video is 'Se o video deve tocar em loop infinito. Quando true, o app NAO pode pausar/interromper esse video ao tocar outro video em outra tela - precisa de player proprio e isolado.';
comment on column island_avatars.crop_scale is 'Zoom aplicado sobre o video/print de referencia (1 = sem zoom).';
comment on column island_avatars.crop_offset_x is 'Deslocamento horizontal do enquadramento, em % (-50 a 50) a partir do centro.';
comment on column island_avatars.crop_offset_y is 'Deslocamento vertical do enquadramento, em % (-50 a 50) a partir do centro.';

alter table max_lessons add column if not exists muted boolean not null default false;
alter table max_lessons add column if not exists volume numeric not null default 1;
alter table max_lessons add column if not exists loop_video boolean not null default false;
comment on column max_lessons.muted is 'Se a aula deve tocar sem som por padrao no app.';
comment on column max_lessons.volume is 'Volume (0 a 1) quando nao mudo.';
comment on column max_lessons.loop_video is 'Se a aula deve repetir em loop ao terminar (a maioria das aulas nao precisa; default false).';

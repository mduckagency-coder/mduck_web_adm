-- ============================================================================
-- Premiacoes de programa passam a permitir cadastro manual (sem vincular a
-- um streamer, igual ja funciona em Eventos > Premiacoes) e ganham o status
-- "agendado" entre pendente e entregue. Rode manualmente no SQL Editor do
-- Supabase. Aditivo: nao altera nem apaga dados existentes.
-- ============================================================================

alter table program_awards alter column streamer_id drop not null;
alter table program_awards drop constraint if exists program_awards_streamer_id_fkey;
alter table program_awards add constraint program_awards_streamer_id_fkey foreign key (streamer_id) references profiles(id) on delete set null;

alter table program_awards drop constraint if exists program_awards_status_check;
alter table program_awards add constraint program_awards_status_check check (status in ('pendente', 'agendado', 'entregue'));

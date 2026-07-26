-- ============================================================================
-- Imagem do programa (quadrado pequeno no card da lista e ao lado da
-- descricao no detalhe, mesmo padrao ja usado em Eventos). Rode manualmente
-- no SQL Editor do Supabase. Aditivo: nao altera nem apaga dados existentes.
--
-- OBS: "dias validados" (streamer_stats.days_live) e "batalhas por
-- categoria" NAO exigem coluna nova -- entram no jsonb
-- development_programs.criteria que ja existe.
-- ============================================================================

alter table development_programs add column if not exists image_url text;

insert into storage.buckets (id, name, public)
values ('program_banners', 'program_banners', true)
on conflict (id) do nothing;

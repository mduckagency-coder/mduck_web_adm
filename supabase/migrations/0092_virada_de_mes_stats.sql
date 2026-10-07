-- ============================================================================
-- Virada de mes em streamer_stats.
--
-- Problema: streamer_stats guarda o "mes atual", mas so e sobrescrito quando
-- a planilha do TikTok e importada. Quem nao aparece na planilha do mes novo
-- (ex.: nao fez live ainda) ficava com os numeros do mes passado, e o app
-- mostrava isso como se fosse deste mes (Ranking, Home, Ilha Top, Missoes...).
--
-- Solucao:
--   * streamer_stats.period_key ('AAAA-MM') = mes a que os numeros pertencem
--     (a importacao passa a gravar o periodo da planilha).
--   * virar_mes_streamer_stats(): para toda linha de mes anterior, guarda os
--     numeros em monthly_stats (se o mes ainda nao estiver la) e zera a linha
--     para o mes atual. Idempotente.
--   * roda agora, ao fim de cada importacao (painel) e todo dia 00:05
--     (horario de Brasilia) via pg_cron, quando disponivel.
--
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

alter table streamer_stats add column if not exists period_key text;

-- linhas antigas: o mes vem da data da ultima atualizacao
update streamer_stats
set period_key = to_char(coalesce(updated_at, now()) at time zone 'America/Sao_Paulo', 'YYYY-MM')
where period_key is null;

create or replace function virar_mes_streamer_stats()
returns int
language plpgsql volatile security definer
set search_path = public
as $$
declare
  v_cur text := to_char(now() at time zone 'America/Sao_Paulo', 'YYYY-MM');
  v_count int;
begin
  -- 1) nao perde nada: o mes que esta saindo vai pro historico se ainda nao
  --    existir la (a importacao seguinte sobrescreve com o numero final).
  insert into monthly_stats (streamer_id, period_key, diamonds, hours_live, days_live, closed_at)
  select s.streamer_id, s.period_key, coalesce(s.diamonds, 0), coalesce(s.hours_live, 0), coalesce(s.days_live, 0), now()
  from streamer_stats s
  where s.period_key is not null and s.period_key < v_cur
  on conflict (streamer_id, period_key) do nothing;

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

-- aplica ja (corrige quem esta com numeros de setembro agora)
select virar_mes_streamer_stats();

-- agenda diaria 00:05 de Brasilia (03:05 UTC). Se o pg_cron nao estiver
-- habilitado no projeto, so pula -- a importacao e o app ja chamam a funcao.
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    null;
  end;
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    begin
      perform cron.unschedule('mduck_virada_mes_stats');
    exception when others then
      null;
    end;
    perform cron.schedule('mduck_virada_mes_stats', '5 3 * * *', 'select public.virar_mes_streamer_stats()');
  end if;
end $$;

notify pgrst, 'reload schema';

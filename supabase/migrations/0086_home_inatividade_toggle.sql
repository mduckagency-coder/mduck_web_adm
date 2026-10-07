-- ============================================================================
-- Background Home: liga/desliga da Inatividade (botao na aba Inatividade do
-- painel). Fica em app_settings, chave 'home_inactivity_enabled' (true/false)
-- por agencia. Sem a chave = ligado (comportamento da 0085).
-- Desligado: ninguem entra no estado de inatividade -- todo mundo ve os
-- videos normais, mesmo quem esta ha mais de 7 dias sem live.
--
-- So recria a funcao home_pick_background (mesma assinatura, o app nao muda).
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase (depois
-- da 0085_home_backgrounds_inatividade.sql).
-- ============================================================================

create or replace function home_pick_background(p_agency_id uuid, p_streamer_id uuid, p_at timestamptz default now())
returns home_backgrounds
language plpgsql stable
as $$
declare
  v_local timestamp := p_at at time zone 'America/Sao_Paulo';
  v_time time := v_local::time;
  v_day text := to_char(v_local, 'YYYY-MM-DD');
  v_last_live timestamptz;
  v_setting jsonb;
  v_category text := 'normal';
  v_row home_backgrounds;
begin
  -- 0. inatividade ligada pra agencia? (sem configuracao = ligada)
  select value into v_setting from app_settings
  where agency_id = p_agency_id and key = 'home_inactivity_enabled'
  limit 1;

  -- 1. estado do streamer: inativo = mais de 7 dias sem live
  if p_streamer_id is not null
     and (v_setting is null or v_setting::text not in ('false', '"false"')) then
    select last_live_at into v_last_live from profiles where id = p_streamer_id;
    if v_last_live is not null
       and p_at - v_last_live > interval '7 days'
       and exists (
         select 1 from home_backgrounds
         where agency_id = p_agency_id and is_active and category = 'inactivity'
       ) then
      v_category := 'inactivity';
    end if;
  end if;

  -- 2. dentro da categoria, as mesmas regras de sempre:
  --    fixo na janela > aleatorio na janela (sorteio do dia) > qualquer ativo
  select * into v_row from home_backgrounds
  where agency_id = p_agency_id and is_active and category = v_category and mode = 'fixed'
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by sort_order, created_at
  limit 1;
  if found then return v_row; end if;

  select * into v_row from home_backgrounds
  where agency_id = p_agency_id and is_active and category = v_category
    and (case when start_time <= end_time then v_time between start_time and end_time
              else v_time >= start_time or v_time <= end_time end)
  order by md5(id::text || coalesce(p_streamer_id::text, '') || v_day)
  limit 1;
  if found then return v_row; end if;

  select * into v_row from home_backgrounds
  where agency_id = p_agency_id and is_active and category = v_category
  order by md5(id::text || coalesce(p_streamer_id::text, '') || v_day)
  limit 1;
  return v_row;
end;
$$;

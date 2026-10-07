-- ============================================================================
-- Background Home: categoria "Inatividade".
--
-- Os videos continuam na mesma tabela home_backgrounds, com as mesmas regras
-- de horario e fixo/aleatorio. So ganham:
--   category      'normal' (padrao, todos os videos ja cadastrados) ou
--                 'inactivity' (ilha sem o pato, pra quem esta sem live)
--   overlay_text  texto exibido sobre o video (usado nos de inatividade)
--
-- Inatividade e um ESTADO do streamer, nao um horario: se a ultima live
-- (profiles.last_live_at, gravada pela Importacao TikTok) foi ha mais de 7
-- dias, a funcao home_pick_background passa a escolher SO entre os videos de
-- inatividade -- e dentro deles respeita a janela de horario normalmente.
-- Quando o streamer volta a fazer live, a data atualiza na importacao e ele
-- volta sozinho pros videos normais. Sem data de ultima live = ativo.
-- Se a agencia ainda nao cadastrou nenhum video de inatividade ativo, o
-- streamer inativo continua vendo os normais (nunca fica sem fundo).
--
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase (depois
-- da 0084_home_backgrounds.sql).
-- ============================================================================

alter table home_backgrounds add column if not exists category text not null default 'normal';
alter table home_backgrounds drop constraint if exists home_backgrounds_category_check;
alter table home_backgrounds add constraint home_backgrounds_category_check check (category in ('normal', 'inactivity'));
alter table home_backgrounds add column if not exists overlay_text text;

create index if not exists idx_home_backgrounds_category on home_backgrounds(agency_id, category, is_active);

comment on column home_backgrounds.category is 'normal = programacao do dia a dia; inactivity = usado so quando o streamer esta ha mais de 7 dias sem live (profiles.last_live_at).';
comment on column home_backgrounds.overlay_text is 'Texto mostrado sobre o video na Home (editavel no painel). Usado nos videos de inatividade.';

-- Mesma assinatura da 0084 (o app nao muda a chamada); so passa a decidir a
-- categoria antes de aplicar as regras de horario.
create or replace function home_pick_background(p_agency_id uuid, p_streamer_id uuid, p_at timestamptz default now())
returns home_backgrounds
language plpgsql stable
as $$
declare
  v_local timestamp := p_at at time zone 'America/Sao_Paulo';
  v_time time := v_local::time;
  v_day text := to_char(v_local, 'YYYY-MM-DD');
  v_last_live timestamptz;
  v_category text := 'normal';
  v_row home_backgrounds;
begin
  -- 1. estado do streamer: inativo = mais de 7 dias sem live
  if p_streamer_id is not null then
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

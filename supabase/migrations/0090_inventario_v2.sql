-- ============================================================================
-- Inventario v2: historico do que o streamer recebeu, conquistou ou viveu
-- com a MDUCK Agency. Reaproveita a tabela streamer_inventory_entries (0059)
-- -- nenhum dado e duplicado:
--   painel  Home Central > Inventario   cadastro e gestao
--   CRM     linha do tempo do streamer  le esta mesma tabela
--   app     Inventario/Mochila          le esta mesma tabela (so o visivel)
--
-- O que muda:
--   * tipos novos: presente, treinamento, conquista, recompensa, campanha,
--     evento, suporte, pix, reconhecimento, outros
--     (os antigos viram: acompanhamento -> suporte, premiacao -> recompensa)
--   * amount            valor opcional (Pix, premiacao, bonus...)
--   * show_amount       se o valor aparece pro streamer no app
--   * visible_to_streamer  false = registro interno (so painel/CRM)
--   * internal_note     observacao interna (nunca vai pro app)
--   * status            concluido | pendente | cancelado
--   * updated_at / updated_by
--   * points (XP) deixa de ser usado; a coluna fica pra nao perder dados
--
-- Seguranca: o app deixa de ler a tabela direto (o select do streamer
-- devolveria a observacao interna e os registros internos). Passa a usar a
-- funcao app_my_inventory(), que so devolve o que e visivel, sem nota interna
-- e com o valor apenas quando show_amount = true.
--
-- Aditivo/idempotente, rode manualmente no SQL Editor do Supabase.
-- ============================================================================

-- 1. tipos
alter table streamer_inventory_entries drop constraint if exists streamer_inventory_entries_category_check;
update streamer_inventory_entries set category = 'suporte' where category = 'acompanhamento';
update streamer_inventory_entries set category = 'recompensa' where category = 'premiacao';
alter table streamer_inventory_entries add constraint streamer_inventory_entries_category_check
  check (category in ('presente', 'treinamento', 'conquista', 'recompensa', 'campanha', 'evento', 'suporte', 'pix', 'reconhecimento', 'outros'));

-- 2. colunas novas
alter table streamer_inventory_entries add column if not exists amount numeric(12, 2);
alter table streamer_inventory_entries add column if not exists show_amount boolean not null default true;
alter table streamer_inventory_entries add column if not exists visible_to_streamer boolean not null default true;
alter table streamer_inventory_entries add column if not exists internal_note text;
alter table streamer_inventory_entries add column if not exists status text not null default 'concluido';
alter table streamer_inventory_entries drop constraint if exists streamer_inventory_entries_status_check;
alter table streamer_inventory_entries add constraint streamer_inventory_entries_status_check
  check (status in ('concluido', 'pendente', 'cancelado'));
alter table streamer_inventory_entries add column if not exists updated_at timestamptz not null default now();
alter table streamer_inventory_entries add column if not exists updated_by uuid references managers(id);

comment on column streamer_inventory_entries.points is 'Legado (XP) -- nao e mais exibido em lugar nenhum.';
comment on column streamer_inventory_entries.visible_to_streamer is 'false = registro interno da agencia (aparece so no painel/CRM, nunca no app).';
comment on column streamer_inventory_entries.internal_note is 'Observacao interna. Nunca e enviada pro app.';
comment on column streamer_inventory_entries.show_amount is 'Se o valor (amount) aparece pro streamer no app.';

-- 3. o app nao le mais a tabela direto
drop policy if exists "streamer_inventory_streamer_select" on streamer_inventory_entries;

-- 4. leitura segura pro app: so o que e visivel, sem nota interna
create or replace function app_my_inventory()
returns table (
  id uuid,
  category text,
  title text,
  description text,
  occurred_at date,
  image_url text,
  amount numeric,
  status text
)
language sql stable security definer
set search_path = public
as $$
  select
    e.id, e.category, e.title, e.description, e.occurred_at, e.image_url,
    case when e.show_amount then e.amount else null end as amount,
    e.status
  from streamer_inventory_entries e
  join profiles p on p.id = e.streamer_id
  where p.auth_user_id = auth.uid()
    and e.visible_to_streamer
    and e.status <> 'cancelado'
  order by e.occurred_at desc, e.created_at desc;
$$;

grant execute on function app_my_inventory() to authenticated;

-- 5. a configuracao do "mascote do inventario" saiu do produto
delete from app_settings where key = 'inventory_mascot_url';

notify pgrst, 'reload schema';

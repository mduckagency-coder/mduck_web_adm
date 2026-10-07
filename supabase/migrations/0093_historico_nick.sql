-- ============================================================================
-- Historico de troca de nick do TikTok.
--
-- O ID do TikTok (profiles.tiktok_creator_id) nunca muda; o @ (tiktok_username)
-- pode mudar. Todo o sistema (app e painel) liga os dados pelo profiles.id,
-- entao metricas, conquistas, inventario, CRM etc. continuam na mesma pessoa.
-- A importacao do TikTok acha a pessoa pelo ID e atualiza o @ sozinha; este
-- trigger guarda cada troca (venha de onde vier: importacao ou edicao manual)
-- pra aparecer no CRM.
--
-- Rode manualmente no SQL Editor do Supabase.
-- ============================================================================

create table if not exists tiktok_nick_history (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid,
  streamer_id uuid not null references profiles(id) on delete cascade,
  tiktok_creator_id text,
  old_nick text not null,
  new_nick text not null,
  changed_at timestamptz not null default now()
);
create index if not exists idx_tiktok_nick_history_streamer on tiktok_nick_history(streamer_id, changed_at desc);
create index if not exists idx_tiktok_nick_history_old on tiktok_nick_history(lower(old_nick));

alter table tiktok_nick_history enable row level security;

drop policy if exists "tiktok_nick_history_agency" on tiktok_nick_history;
create policy "tiktok_nick_history_agency" on tiktok_nick_history
  for select using (agency_id = (select agency_id from managers where id = auth.uid()));

create or replace function trg_profiles_nick_history()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if coalesce(trim(old.tiktok_username), '') <> ''
     and coalesce(trim(new.tiktok_username), '') <> ''
     and lower(trim(old.tiktok_username)) <> lower(trim(new.tiktok_username)) then
    insert into tiktok_nick_history (agency_id, streamer_id, tiktok_creator_id, old_nick, new_nick)
    values (new.agency_id, new.id, new.tiktok_creator_id::text, trim(old.tiktok_username), trim(new.tiktok_username));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_nick_history on profiles;
create trigger trg_profiles_nick_history
  after update of tiktok_username on profiles
  for each row execute function trg_profiles_nick_history();

notify pgrst, 'reload schema';

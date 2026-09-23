-- =============================================================
-- Migração: adiciona NPCs, os itens que vendem (npc_shop_items) e o
-- vínculo de qual NPC concede cada missão (missions.giver_npc_id).
-- Rode isso no SQL Editor do Supabase se você já tinha rodado o
-- schema.sql antes desta mudança. Se estiver rodando o schema.sql do
-- zero, pode ignorar este arquivo — ele já está incluído lá.
-- =============================================================

do $$ begin
  create type npc_role as enum ('vendedor', 'concede_missao', 'parte_missao', 'outro');
exception
  when duplicate_object then null;
end $$;

create table if not exists npcs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  roles npc_role[] not null default '{}',
  description text,

  arco_id text references arcos(id) on delete set null,
  pin_id uuid references pins(id) on delete set null,
  location_note text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists npcs_arco_id_idx on npcs (arco_id);
create index if not exists npcs_pin_id_idx on npcs (pin_id);
create index if not exists npcs_roles_idx on npcs using gin (roles);

create table if not exists npc_shop_items (
  id uuid primary key default gen_random_uuid(),
  npc_id uuid not null references npcs(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  price integer not null default 0,
  stock integer,
  created_at timestamptz not null default now(),

  constraint npc_shop_items_price_positive check (price >= 0),
  unique (npc_id, item_id)
);

create index if not exists npc_shop_items_npc_id_idx on npc_shop_items (npc_id);
create index if not exists npc_shop_items_item_id_idx on npc_shop_items (item_id);

alter table missions add column if not exists giver_npc_id uuid references npcs(id) on delete set null;
create index if not exists missions_giver_npc_id_idx on missions (giver_npc_id);

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists npcs_set_updated_at on npcs;
create trigger npcs_set_updated_at
  before update on npcs
  for each row execute function set_updated_at();

alter table npcs enable row level security;
alter table npc_shop_items enable row level security;

drop policy if exists npcs_public_read on npcs;
create policy npcs_public_read on npcs for select using (true);

drop policy if exists npcs_auth_write on npcs;
create policy npcs_auth_write on npcs for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists npc_shop_items_public_read on npc_shop_items;
create policy npc_shop_items_public_read on npc_shop_items for select using (true);

drop policy if exists npc_shop_items_auth_write on npc_shop_items;
create policy npc_shop_items_auth_write on npc_shop_items for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

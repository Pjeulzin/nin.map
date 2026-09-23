-- =============================================================
-- Migração: adiciona catálogo de itens, mobs e os drops que
-- relacionam os dois.
-- Rode isso no SQL Editor do Supabase se você já tinha rodado o
-- schema.sql antes desta mudança. Se estiver rodando o schema.sql do
-- zero, pode ignorar este arquivo — ele já está incluído lá.
-- =============================================================

do $$ begin
  create type item_type as enum ('anel', 'arma', 'roupa', 'consumivel', 'item_mob');
exception
  when duplicate_object then null;
end $$;

create table if not exists items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type item_type not null default 'item_mob',
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists items_type_idx on items (type);
create unique index if not exists items_name_unique_idx on items (lower(name));

do $$ begin
  create type mob_category as enum ('boss', 'enfurecido', 'regular');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type mob_combat_type as enum ('passivo', 'agressivo');
exception
  when duplicate_object then null;
end $$;

create table if not exists mobs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category mob_category not null default 'regular',
  level integer not null default 1,

  arco_id text references arcos(id) on delete set null,
  pin_id uuid references pins(id) on delete set null,
  location_note text,

  hp integer not null default 1,
  damage_min integer,
  damage_max integer,
  combat_type mob_combat_type not null default 'agressivo',

  xp_reward integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint mobs_damage_range check (
    damage_min is null or damage_max is null or damage_min <= damage_max
  )
);

create index if not exists mobs_category_idx on mobs (category);
create index if not exists mobs_arco_id_idx on mobs (arco_id);
create index if not exists mobs_pin_id_idx on mobs (pin_id);

create table if not exists mob_drops (
  id uuid primary key default gen_random_uuid(),
  mob_id uuid not null references mobs(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  quantity_min integer not null default 1,
  quantity_max integer not null default 1,
  drop_rate numeric(5, 2),
  created_at timestamptz not null default now(),

  constraint mob_drops_quantity_range check (quantity_min <= quantity_max),
  constraint mob_drops_rate_range check (
    drop_rate is null or (drop_rate >= 0 and drop_rate <= 100)
  ),
  unique (mob_id, item_id)
);

create index if not exists mob_drops_mob_id_idx on mob_drops (mob_id);
create index if not exists mob_drops_item_id_idx on mob_drops (item_id);

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists items_set_updated_at on items;
create trigger items_set_updated_at
  before update on items
  for each row execute function set_updated_at();

drop trigger if exists mobs_set_updated_at on mobs;
create trigger mobs_set_updated_at
  before update on mobs
  for each row execute function set_updated_at();

alter table items enable row level security;
alter table mobs enable row level security;
alter table mob_drops enable row level security;

drop policy if exists items_public_read on items;
create policy items_public_read on items for select using (true);

drop policy if exists items_auth_write on items;
create policy items_auth_write on items for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists mobs_public_read on mobs;
create policy mobs_public_read on mobs for select using (true);

drop policy if exists mobs_auth_write on mobs;
create policy mobs_auth_write on mobs for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists mob_drops_public_read on mob_drops;
create policy mob_drops_public_read on mob_drops for select using (true);

drop policy if exists mob_drops_auth_write on mob_drops;
create policy mob_drops_auth_write on mob_drops for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

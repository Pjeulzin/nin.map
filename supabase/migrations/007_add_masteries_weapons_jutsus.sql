-- Migração 007: maestrias, extensão de armas nos itens, e jutsus.
-- Rode isso se você já tinha rodado uma versão anterior do schema.
-- Se você está instalando do zero, só rode o schema.sql — ele já
-- inclui essas mudanças.

-- ---------------------------------------------------------------
-- Maestrias (masteries)
-- ---------------------------------------------------------------
create table if not exists masteries (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into masteries (slug, name) values
  ('fogo', 'Fogo'),
  ('vento', 'Vento'),
  ('raio', 'Raio'),
  ('terra', 'Terra'),
  ('agua', 'Água'),
  ('medicina', 'Medicina'),
  ('arma', 'Arma'),
  ('taijutsu', 'Taijutsu')
on conflict (slug) do nothing;

create table if not exists mastery_branches (
  id uuid primary key default gen_random_uuid(),
  mastery_id uuid not null references masteries(id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (mastery_id, name)
);

create index if not exists mastery_branches_mastery_id_idx on mastery_branches (mastery_id);

insert into mastery_branches (mastery_id, name)
select id, branch_name
from masteries, (values ('Foco em Chakra'), ('Foco em Dano (Intelecto)')) as b(branch_name)
where masteries.slug = 'medicina'
on conflict (mastery_id, name) do nothing;

-- ---------------------------------------------------------------
-- Armas (extensão do cadastro de itens)
-- ---------------------------------------------------------------
do $$ begin
  create type weapon_category as enum ('espada', 'kunai', 'shuriken', 'bastao', 'outro');
exception
  when duplicate_object then null;
end $$;

alter table items add column if not exists weapon_category weapon_category;
alter table items add column if not exists base_damage integer;
alter table items add column if not exists attack_range integer;
alter table items add column if not exists weapon_mastery_id uuid references masteries(id) on delete set null;

create index if not exists items_weapon_mastery_id_idx on items (weapon_mastery_id);

-- ---------------------------------------------------------------
-- Jutsus
-- ---------------------------------------------------------------
create table if not exists jutsus (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mastery_id uuid references masteries(id) on delete set null,
  mastery_branch_id uuid references mastery_branches(id) on delete set null,
  rank mission_rank,
  level_required integer,
  chakra_cost integer,
  cooldown_seconds integer,
  description text,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists jutsus_mastery_id_idx on jutsus (mastery_id);
create index if not exists jutsus_mastery_branch_id_idx on jutsus (mastery_branch_id);
create index if not exists jutsus_rank_idx on jutsus (rank);

-- ---------------------------------------------------------------
-- updated_at automático + RLS
-- ---------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists masteries_set_updated_at on masteries;
create trigger masteries_set_updated_at
  before update on masteries
  for each row execute function set_updated_at();

drop trigger if exists mastery_branches_set_updated_at on mastery_branches;
create trigger mastery_branches_set_updated_at
  before update on mastery_branches
  for each row execute function set_updated_at();

drop trigger if exists jutsus_set_updated_at on jutsus;
create trigger jutsus_set_updated_at
  before update on jutsus
  for each row execute function set_updated_at();

alter table masteries enable row level security;
alter table mastery_branches enable row level security;
alter table jutsus enable row level security;

drop policy if exists masteries_public_read on masteries;
create policy masteries_public_read on masteries for select using (true);

drop policy if exists masteries_auth_write on masteries;
create policy masteries_auth_write on masteries for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists mastery_branches_public_read on mastery_branches;
create policy mastery_branches_public_read on mastery_branches for select using (true);

drop policy if exists mastery_branches_auth_write on mastery_branches;
create policy mastery_branches_auth_write on mastery_branches for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists jutsus_public_read on jutsus;
create policy jutsus_public_read on jutsus for select using (true);

drop policy if exists jutsus_auth_write on jutsus;
create policy jutsus_auth_write on jutsus for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

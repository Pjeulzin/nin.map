-- =============================================================
-- Nin.Map — schema Supabase
-- =============================================================
-- Como usar:
--   1. Crie um projeto em https://supabase.com
--   2. Abra o SQL Editor do projeto e cole este arquivo inteiro, rode.
--   3. Em Project Settings → API, copie a "Project URL" e a "anon public key"
--      e cole em js/supabase-config.js
--   4. Crie um usuário de admin em Authentication → Users → Add user
--      (esse é o login usado em /admin)
-- =============================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------
-- Arcos (mapas instanciados)
-- ---------------------------------------------------------------
create table if not exists arcos (
  id text primary key,           -- mesmo id usado em js/config.js (ex: "20")
  label text not null,           -- ex: "Arco 20"
  created_at timestamptz not null default now()
);

insert into arcos (id, label) values
  ('20', 'Arco 20'),
  ('30', 'Arco 30'),
  ('50', 'Arco 50'),
  ('60', 'Arco 60')
on conflict (id) do nothing;

-- ---------------------------------------------------------------
-- Pins (pontos de interesse no mapa)
-- ---------------------------------------------------------------
do $$ begin
  create type pin_type as enum ('cidade', 'dungeon', 'npc', 'recurso', 'outro');
exception
  when duplicate_object then null;
end $$;

create table if not exists pins (
  id uuid primary key default gen_random_uuid(),
  arco_id text not null references arcos(id) on delete cascade,
  name text not null,
  type pin_type not null default 'outro',
  x numeric not null,            -- coordenada x em pixels na imagem do arco
  y numeric not null,            -- coordenada y em pixels na imagem do arco
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pins_arco_id_idx on pins (arco_id);

-- ---------------------------------------------------------------
-- Missões
-- ---------------------------------------------------------------
-- Tipos de missão do jogo:
--   global  -> disponível em qualquer arco
--   arco    -> exclusiva de um arco específico (exige arco_id)
--   evento  -> missão de evento temporário
--   diaria  -> missão diária, feita no mapa global
-- (missões de RP, feitas por outro player, ficam de fora por enquanto)
do $$ begin
  create type mission_type as enum ('global', 'arco', 'evento', 'diaria');
exception
  when duplicate_object then null;
end $$;

create table if not exists missions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  mission_type mission_type not null default 'global',
  arco_id text references arcos(id) on delete cascade,  -- só quando mission_type = 'arco'

  xp integer not null default 0,
  ryo integer not null default 0,

  -- Nível necessário: guardamos min/max e derivamos o formato na tela
  --   só level_min preenchido        -> "+X" (nível X ou mais)
  --   só level_max preenchido        -> "até X"
  --   os dois preenchidos e iguais   -> "nível X" (exato)
  --   os dois preenchidos, diferentes-> "X até Y"
  level_min integer,
  level_max integer,

  -- Objetivos da missão: lista de { item, quantity }
  -- ex: [{ "item": "Cocoon", "quantity": 40 }, { "item": "Dragonfly Wing", "quantity": 20 }]
  objectives jsonb not null default '[]'::jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint missions_arco_requires_id check (
    (mission_type = 'arco' and arco_id is not null) or
    (mission_type != 'arco')
  ),
  constraint missions_level_range check (
    level_min is null or level_max is null or level_min <= level_max
  )
);

create index if not exists missions_arco_id_idx on missions (arco_id);
create index if not exists missions_type_idx on missions (mission_type);

-- ---------------------------------------------------------------
-- updated_at automático
-- ---------------------------------------------------------------
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists pins_set_updated_at on pins;
create trigger pins_set_updated_at
  before update on pins
  for each row execute function set_updated_at();

drop trigger if exists missions_set_updated_at on missions;
create trigger missions_set_updated_at
  before update on missions
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------
-- Leitura pública (o site mostra pins/missões pra qualquer visitante).
-- Escrita só para usuários autenticados (login em /admin).
alter table arcos enable row level security;
alter table pins enable row level security;
alter table missions enable row level security;

drop policy if exists arcos_public_read on arcos;
create policy arcos_public_read on arcos for select using (true);

drop policy if exists pins_public_read on pins;
create policy pins_public_read on pins for select using (true);

drop policy if exists pins_auth_write on pins;
create policy pins_auth_write on pins for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists missions_public_read on missions;
create policy missions_public_read on missions for select using (true);

drop policy if exists missions_auth_write on missions;
create policy missions_auth_write on missions for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

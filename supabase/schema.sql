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
-- Vilas (Névoa, Folha, Areia, Renegados)
-- ---------------------------------------------------------------
-- O jogador escolhe uma vila pra jogar; cada uma pode ter suas
-- próprias variações de missão (mesma missão, itens diferentes pra
-- coletar). Pins também vão poder ser filtrados por vila no futuro.
create table if not exists villages (
  id text primary key,           -- mesmo id usado em js/config.js (ex: "neblina")
  label text not null,           -- ex: "Névoa"
  created_at timestamptz not null default now()
);

insert into villages (id, label) values
  ('neblina', 'Névoa'),
  ('folha', 'Folha'),
  ('areia', 'Areia'),
  ('renegados', 'Renegados')
on conflict (id) do nothing;

-- Função de trigger reaproveitada por toda tabela com `updated_at`.
-- Definida aqui, bem cedo, porque numa instalação nova (rodando este
-- arquivo do zero) o Postgres exige que a função já exista antes de
-- qualquer `create trigger ... execute function set_updated_at()` —
-- e algumas seções mais abaixo (ex: Proficiências, Montarias) criam
-- seus próprios triggers antes do bloco consolidado de triggers no
-- fim do arquivo. `create or replace` deixa repetir a definição mais
-- abaixo sem problema.
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

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

-- Rank de dificuldade da missão: S (mais difícil) até D (mais fácil)
do $$ begin
  create type mission_rank as enum ('S', 'A', 'B', 'C', 'D');
exception
  when duplicate_object then null;
end $$;

create table if not exists missions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  mission_type mission_type not null default 'global',
  arco_id text references arcos(id) on delete cascade,  -- só quando mission_type = 'arco'
  rank mission_rank not null default 'D',

  -- Vila dona desta variante da missão. Use quando a mesma missão (ex:
  -- "Medicine Supplies I") pede itens diferentes dependendo da vila —
  -- nesse caso cria-se uma linha por vila, todas com o mesmo `name`
  -- mas `village_id` e `objectives` diferentes. Deixe null quando a
  -- missão for igual pra qualquer vila (ou não fizer sentido por vila).
  village_id text references villages(id) on delete cascade,

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
create index if not exists missions_rank_idx on missions (rank);
create index if not exists missions_village_id_idx on missions (village_id);

-- ---------------------------------------------------------------
-- Itens
-- ---------------------------------------------------------------
-- Catálogo de itens do jogo — usado tanto pra descrever equipamentos
-- quanto materiais que os mobs dropam (ex: Cocoon, Dragonfly Wing).
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
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists items_type_idx on items (type);
create unique index if not exists items_name_unique_idx on items (lower(name));

-- Bucket de storage pra o ícone de cada item (upload feito pelo admin).
-- Leitura pública (pra aparecer no site), escrita só autenticada.
insert into storage.buckets (id, name, public)
values ('item-icons', 'item-icons', true)
on conflict (id) do nothing;

do $$ begin
  create policy "item_icons_public_read"
    on storage.objects for select
    using (bucket_id = 'item-icons');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create policy "item_icons_auth_write"
    on storage.objects for insert
    with check (bucket_id = 'item-icons' and auth.role() = 'authenticated');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create policy "item_icons_auth_update"
    on storage.objects for update
    using (bucket_id = 'item-icons' and auth.role() = 'authenticated');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create policy "item_icons_auth_delete"
    on storage.objects for delete
    using (bucket_id = 'item-icons' and auth.role() = 'authenticated');
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------
-- Maestrias (masteries)
-- ---------------------------------------------------------------
-- As 8 maestrias do jogo: 5 elementais (Fogo, Vento, Raio, Terra,
-- Água) + Medicina + Arma (Bukijutsu) + Taijutsu. O jogador escolhe
-- uma no lvl 10 e outra no lvl 50. Algumas maestrias têm
-- ramificações (ex: Medicina se divide em foco em chakra e foco em
-- dano/intelecto) — isso fica em `mastery_branches`, opcional.
create table if not exists masteries (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,   -- ex: "fogo", "medicina" — estável pra referenciar no código
  name text not null,
  description text,
  image_url text,
  -- Chave em inglês igual ao ninforge.xyz (Fire, Water, ...), usada
  -- pelo calculador de build pra casar com os dados importados de lá.
  external_key text,
  -- Texto livre "como jogar essa maestria" (pontos fortes/fracos, PvE
  -- x PvP) — mostrado na página de detalhes (mastery-detail.html).
  playstyle_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into masteries (slug, name, external_key) values
  ('fogo', 'Fogo', 'Fire'),
  ('vento', 'Vento', 'Wind'),
  ('raio', 'Raio', 'Lightning'),
  ('terra', 'Terra', 'Earth'),
  ('agua', 'Água', 'Water'),
  ('medicina', 'Medicina', 'Medical'),
  ('arma', 'Arma', 'Weapon Master'),
  ('taijutsu', 'Taijutsu', 'Taijutsu')
on conflict (slug) do update set external_key = excluded.external_key;

create unique index if not exists masteries_external_key_unique_idx on masteries (external_key);

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

-- Exemplo real que você já mencionou — edite/apague em Admin → Maestrias.
insert into mastery_branches (mastery_id, name)
select id, branch_name
from masteries, (values ('Foco em Chakra'), ('Foco em Dano (Intelecto)')) as b(branch_name)
where masteries.slug = 'medicina'
on conflict (mastery_id, name) do nothing;

-- ---------------------------------------------------------------
-- Armas (extensão do cadastro de itens)
-- ---------------------------------------------------------------
-- Uma arma continua sendo um item comum (type = 'arma'), só que com
-- campos extras usados na futura tela de builds: categoria da arma,
-- dano/alcance base, e a maestria com que ela tem sinergia.
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

-- weapon_category (acima) era um chute inicial de 5 categorias. O
-- jogo de verdade usa 6 grupos de arma (Blunt, Fan, Fist, Pipe, Seven
-- Blades, Sword), cada arma é um MODELO específico com seus próprios
-- requisitos (nível + atributo) e bônus — é isso que o calculador de
-- build (`builds.html`) usa. weapon_category/weapon_mastery_id acima
-- continuam existindo (não quebra nada), só não são mais usados pra
-- armas novas.
do $$ begin
  create type weapon_group as enum ('Blunt', 'Fan', 'Fist', 'Pipe', 'Seven Blades', 'Sword');
exception
  when duplicate_object then null;
end $$;

alter table items add column if not exists weapon_group weapon_group;
alter table items add column if not exists weapon_requirements jsonb;
alter table items add column if not exists weapon_buffs jsonb;
alter table items add column if not exists weapon_rarity text;
alter table items add column if not exists weapon_agi_scaling boolean not null default false;

create index if not exists items_weapon_group_idx on items (weapon_group);

-- Bucket de storage "item-icons" (criado acima) é reaproveitado pros
-- ícones de maestria e de jutsu também — é só um bucket genérico de
-- imagens públicas, não precisa de um por tabela.

-- ---------------------------------------------------------------
-- Mobs
-- ---------------------------------------------------------------
do $$ begin
  create type mob_category as enum ('boss', 'enfurecido', 'regular');
exception
  when duplicate_object then null;
end $$;

-- Passivo = só ataca se for atacado primeiro. Agressivo = ataca ao avistar.
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

  -- Localização: por enquanto texto livre + arco; quando o pin desse
  -- mob existir no mapa, vincule via pin_id (fica null até lá).
  arco_id text references arcos(id) on delete set null,
  pin_id uuid references pins(id) on delete set null,
  location_note text,

  hp integer not null default 1,
  damage_min integer,
  damage_max integer,
  combat_type mob_combat_type not null default 'agressivo',

  xp_reward integer not null default 0,

  -- Detalhe extra pra página de detalhes (mob-detail.html), no mesmo
  -- espírito das páginas de mob do ninonline.fandom.com/wiki: lore /
  -- comportamento em texto livre, imagem e lista de habilidades
  -- especiais nomeadas (ex: "Mountain Crash", "Body Flicker").
  description text,
  image_url text,
  special_abilities text[] not null default '{}',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint mobs_damage_range check (
    damage_min is null or damage_max is null or damage_min <= damage_max
  )
);

create index if not exists mobs_category_idx on mobs (category);
create index if not exists mobs_arco_id_idx on mobs (arco_id);
create index if not exists mobs_pin_id_idx on mobs (pin_id);

-- ---------------------------------------------------------------
-- Drops (relação mobs <-> itens)
-- ---------------------------------------------------------------
create table if not exists mob_drops (
  id uuid primary key default gen_random_uuid(),
  mob_id uuid not null references mobs(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  quantity_min integer not null default 1,
  quantity_max integer not null default 1,
  drop_rate numeric(5, 2),   -- % de chance de drop (0 a 100), opcional
  created_at timestamptz not null default now(),

  constraint mob_drops_quantity_range check (quantity_min <= quantity_max),
  constraint mob_drops_rate_range check (
    drop_rate is null or (drop_rate >= 0 and drop_rate <= 100)
  ),
  unique (mob_id, item_id)
);

create index if not exists mob_drops_mob_id_idx on mob_drops (mob_id);
create index if not exists mob_drops_item_id_idx on mob_drops (item_id);

-- ---------------------------------------------------------------
-- NPCs
-- ---------------------------------------------------------------
-- Um NPC pode acumular vários papéis ao mesmo tempo (vende itens E
-- concede missão, por exemplo) — por isso `roles` é uma lista.
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
  image_url text,

  -- Localização: mesmo padrão dos mobs — texto livre + arco até o pin
  -- desse NPC existir no mapa.
  arco_id text references arcos(id) on delete set null,
  pin_id uuid references pins(id) on delete set null,
  location_note text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists npcs_arco_id_idx on npcs (arco_id);
create index if not exists npcs_pin_id_idx on npcs (pin_id);
create index if not exists npcs_roles_idx on npcs using gin (roles);

-- Itens que um NPC vende (papel "vendedor").
create table if not exists npc_shop_items (
  id uuid primary key default gen_random_uuid(),
  npc_id uuid not null references npcs(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  price integer not null default 0,   -- em ryo
  stock integer,                       -- null = estoque ilimitado
  created_at timestamptz not null default now(),

  constraint npc_shop_items_price_positive check (price >= 0),
  unique (npc_id, item_id)
);

create index if not exists npc_shop_items_npc_id_idx on npc_shop_items (npc_id);
create index if not exists npc_shop_items_item_id_idx on npc_shop_items (item_id);

-- Missão concedida por um NPC (papel "concede_missao"). Fica na
-- própria missão porque cada missão tem só um NPC que a concede.
alter table missions add column if not exists giver_npc_id uuid references npcs(id) on delete set null;
create index if not exists missions_giver_npc_id_idx on missions (giver_npc_id);

-- ---------------------------------------------------------------
-- Jutsus
-- ---------------------------------------------------------------
create table if not exists jutsus (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mastery_id uuid references masteries(id) on delete set null,
  mastery_branch_id uuid references mastery_branches(id) on delete set null,
  rank mission_rank,   -- reaproveita o mesmo enum S/A/B/C/D das missões
  level_required integer,
  chakra_cost integer,
  cooldown_seconds integer,
  description text,
  image_url text,
  -- Requisito de atributo + dano base/escala, usados pelo calculador
  -- de build (mesma lógica do ninforge.xyz). stat_req_stat usa as
  -- siglas do jogo: str/for/int/agi/cha.
  stat_req_stat text,
  stat_req_value integer,
  base_damage integer,
  scaling numeric(4,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists jutsus_mastery_id_idx on jutsus (mastery_id);
create index if not exists jutsus_mastery_branch_id_idx on jutsus (mastery_branch_id);
create index if not exists jutsus_rank_idx on jutsus (rank);
create unique index if not exists jutsus_mastery_name_unique_idx on jutsus (mastery_id, name);

-- ---------------------------------------------------------------
-- Dados reais do jogo (armas e jutsus), extraídos do ninforge.xyz,
-- pra alimentar o calculador de build (`builds.html`) já com os 59
-- modelos de arma e ~90 jutsus do jogo.
-- ---------------------------------------------------------------

insert into items (name, type, description, image_url, base_damage, attack_range, weapon_group, weapon_requirements, weapon_buffs, weapon_rarity, weapon_agi_scaling) values
  ('Bo Staff', 'arma', 'A hand-carved bo staff used for martial arts its extended length allows the user to reach further than a common sword.', null, 24, 1, 'Blunt', '{"Level": 25, "Fortitude": 25, "Intellect": 45}'::jsonb, '{}'::jsonb, 'Uncommon', false),
  ('Reinforced Bo Staff', 'arma', 'A hand-carved bo staff used for martial arts its extended length allows the user to reach further than a common sword.', null, 27, 2, 'Blunt', '{"Level": 25, "Fortitude": 25, "Intellect": 45}'::jsonb, '{"Range": "+1"}'::jsonb, 'Unique', false),
  ('Cursed Staff', 'arma', 'A dark staff imbued with curse energy. Grants a 15% Intellect buff at the cost of a 15% Fortitude debuff.', null, 30, null, 'Blunt', '{"Level": 30, "Intellect": 50}'::jsonb, '{"Intellect": "15%", "Fortitude": "-15%"}'::jsonb, 'Rare', false),
  ('Adamantine Staff', 'arma', 'An adamantine staff as hard as diamond, making it very destructive. Has a large area of attack and provides some defense.', null, 36, 2, 'Blunt', '{"Level": 57, "Fortitude": 50, "Intellect": 90}'::jsonb, '{"Range": "+1", "Fortitude": "+3"}'::jsonb, 'Legendary', false),
  ('Metal Tonfa', 'arma', 'Tonfa made by the best quality wood, that could easly block any sword attack. Tonfa increases melee hits by 19 but slows down your attacks to a base 0.8s per swing.', null, 30, null, 'Blunt', '{"Level": 25, "Agility": 60}'::jsonb, '{"Fortitude": "+5"}'::jsonb, 'Rare', true),
  ('Wooden Tonfa', 'arma', 'Tonfa made by the best quality wood, that could easly block any sword attack. Tonfa increases melee hits by 19 but slows down your attacks to a base 0.8s per swing.', null, 25, null, 'Blunt', '{"Level": 25, "Agility": 60}'::jsonb, '{"Fortitude": "+2"}'::jsonb, 'Rare', true),
  ('Blood Tonfa', 'arma', 'Tonfa made by the best quality wood, and infused with blood engine chakra, that could easly block any sword attack. Tonfa increases melee hits by 25 but slows down your attacks to a base 1s per swing.', null, 35, null, 'Blunt', '{"Level": 53, "Agility": 110}'::jsonb, '{"Fortitude": "+2", "Chakra": "+5", "Life Steal": "5%"}'::jsonb, 'Enchanted', true),
  ('Mizukane', 'arma', 'A finely crafted iron staff curved like a flowing wave, that resonates with the rhythm of its wielder´s chakra. Adds 44 damage, coating each strike in pressurized streams of water.', null, 44, 1, 'Blunt', '{"Level": 60, "Intellect": 120}'::jsonb, '{"Strength": "+1", "Chakra": "+4", "Chakra Steal": "10%"}'::jsonb, 'Legendary', false),
  ('Giant Folding Fan', 'arma', 'A giant folding fan made of iron that sends a wind projectile, able to knock back enemies with wind and deal heavy damage.', null, 36, null, 'Fan', '{"Level": 10, "Strength": 20}'::jsonb, '{}'::jsonb, 'Common', false),
  ('Seji No Hani', 'arma', 'A set of ancient folding fans that shoots a projectile that deals 46 base damage, able to knock back enemies with wind and deal heavy damage.', null, 46, null, 'Fan', '{"Level": 23, "Strength": 40}'::jsonb, '{}'::jsonb, 'Rare', false),
  ('Black Giant Folding Fan', 'arma', 'A giant folding fan made of iron that shoots projectiles across 4 tiles dealing 48 base damage scaling with STR, able to knock back enemies with wind and deal heavy damage.', null, 48, null, 'Fan', '{"Level": 10, "Strength": 20}'::jsonb, '{}'::jsonb, 'Legendary', false),
  ('Hisui Fans', 'arma', 'Twin Fans made of Jade and Gold that shoots projectiles across 4 tiles dealing 36 base damage scaling with STR, knocks back enemies with wind dealing light but quick attacks.', null, 36, null, 'Fan', '{"Level": 35, "Strength": 60, "Agility": 20}'::jsonb, '{"Bonus": "Knockback, Triple Projectile"}'::jsonb, 'Unique', false),
  ('Crystal Fan', 'arma', 'Made of the rarest crafting materials as crystal. Shoots a wind projectile with 8 range that deals 50 base damage, able to knock back enemies with wind and stuns them for 0.5 second.', null, 50, null, 'Fan', '{"Level": 50, "Strength": 80}'::jsonb, '{"Projectiles": "8 Range, 0.5s Snare, Knockback"}'::jsonb, 'Rare', false),
  ('Oriental Fan', 'arma', 'Oriental fan created for requested By Legendary Ninja. Shoots a projectile that pierces enemies and deals 48 base damage across 8 tiles, able to knock back enemies with wind.', null, 48, null, 'Fan', '{"Level": 40, "Strength": 60}'::jsonb, '{"Strength": "+2", "Bonus": "Knockback, Pierce"}'::jsonb, 'Legendary', false),
  ('Blood Iron Fan', 'arma', 'Made of Iron and blood colored fabric. Shoots a wind projectile with 8 range that deals 53 base damage, able to knock back enemies with wind and stuns them for 0.5 second.', null, 53, null, 'Fan', '{"Level": 55, "Strength": 80}'::jsonb, '{"Bonus": "0.5s Snare, Knockback", "Fortitude": "+2", "Life Steal": "10%"}'::jsonb, 'Legendary', false),
  ('Sukarabe Omo', 'arma', 'Twin fans made of Gold and ebony stitching that shoots tornado across 6 tiles dealing 40 base damage scaling with STR, able to stun enemies.', null, 40, null, 'Fan', '{"Level": 60, "Strength": 110}'::jsonb, '{"Bonus": "1 second stun", "Fortitude": "+4", "Intellect": "+2"}'::jsonb, 'Legendary', false),
  ('Nitoryu Fan', 'arma', 'Made of polished obsidian and deep red fabric. Unleashes a twin wind projectile with 6 tiles range that deals 30 base damage per hit with attack speed of 2.2s', null, 30, 6, 'Fan', '{"Level": 53, "Strength": 95, "Agility": 15}'::jsonb, '{"Bonus": "Twin Projectile", "Strength": "+1", "Fortitude": "+1"}'::jsonb, 'Legendary', false),
  ('Hyaku Sutsukesu', 'arma', 'A suitcase filled with a million ryo that shoots projectiles across 4 tiles dealing 55 base damage scaling with STR, able to knock back enemies with the power of money and deal heavy damage.', null, 55, null, 'Fan', '{"Level": 10, "Strength": 20}'::jsonb, '{"Bonus": "Knockback"}'::jsonb, 'Legendary', false),
  ('Kunai Dagger', 'arma', 'A slightly large kunai forged to be wielded like a dagger, adding damage scaling with STR. Does not work as a sword for Kenjutsu!', null, 20, null, 'Fist', '{"Intellect": 10, "Level": 4}'::jsonb, '{}'::jsonb, 'Common', false),
  ('Poison-laced Kunai Dagger', 'arma', 'A slighthly large kunai forged to be wielded like a dagger, adding 25 base damage scaling with STR. Does not work as a sword for Kenjutsu!', null, 25, null, 'Fist', '{"Intellect": 40, "Level": 17}'::jsonb, '{"Bonus": "Applies poison"}'::jsonb, 'Uncommon', false),
  ('Wooden Knuckle Blades', 'arma', 'A wooden blade fitted with finger slots to be worn to enhance knuckle damage while still allowing the user to have full access to handseals and other items. Deals 16 damage every 0.7 seconds', null, 16, null, 'Fist', '{"Agility": 20, "Level": 10}'::jsonb, '{}'::jsonb, 'Common', true),
  ('Blood Knuckle Blades', 'arma', 'Expertly carved from reinforced hardwood and imbued with blood engine chakra, this compact weapon is worn over the knuckles, increasing melee damage by 26 while allowing full use of your fists.', null, 26, null, 'Fist', '{"Agility": 100, "Level": 58}'::jsonb, '{"Chakra": "+5", "Life Steal": "8%"}'::jsonb, 'Enchanted', true),
  ('Metal Knuckle Blades', 'arma', 'Two metal blades that are swift and deadly, pulsing with regenerative chakra that adds damage to fist attacks. Their sleek design channels hits into rapid, precision strikes. Perfect for agility experts.', null, 20, null, 'Fist', '{"Agility": 60, "Chakra": 20, "Level": 30}'::jsonb, '{"Chakra": "+3"}'::jsonb, 'Legendary', true),
  ('Demon Claws', 'arma', 'A pair of large claws worn to inflict more damage on enemies when using Taijutsu, dealing a base damage of 26.', null, 26, null, 'Fist', '{"Agility": 90, "Level": 45}'::jsonb, '{"Agility": "+1", "Bonus": "Bleeding Effect"}'::jsonb, 'Legendary', true),
  ('Bubble-Utilising Pipe', 'arma', 'This bubble pipe can be used to perform bubble ninjutsu. It''s golden in color and bent in the middle. It can create bubbles for many different purposes!', null, 30, null, 'Pipe', '{"Level": 10, "Strength": 20}'::jsonb, '{"Bonus": "Snare"}'::jsonb, 'Common', false),
  ('Rusty Pipe', 'arma', 'This corroded pipe is perfect for performing bubble ninjutsu. It''s a dull brown color with flecks of rust and sharp bend in the middle. It can create bubbles that slows enemies!', null, 30, null, 'Pipe', '{"Level": 28, "Strength": 50}'::jsonb, '{"Bonus": "Slow"}'::jsonb, 'Unique', false),
  ('Seathorn Pipe', 'arma', 'This bubble pipe made in the shape of a rose which can be used to perform bubble ninjutsu. It''s basic bubble attack creates a poisonous bubble trap. Invented by a ninja named "Fuze".', null, 30, null, 'Pipe', '{"Level": 35, "Strength": 80}'::jsonb, '{"Bonus": "Snare, Poison"}'::jsonb, 'Common', false),
  ('Kiryukan Pipe', 'arma', 'This bubble pipe can be used to perform bubble ninjutsu. It''s bloody red in color and bent like a horn. It can create bubbles every 4s for many different purposes!', null, 30, null, 'Pipe', '{"Level": 60, "Strength": 140}'::jsonb, '{"Bonus": "Creates 3 bubbles", "Life Steal": "10%"}'::jsonb, 'Legendary', false),
  ('Crystal Pipe', 'arma', 'A crystal pipe that drains chakra from anyone who touches its bubbles. The effect is subtle at first but becomes clear as their energy thins.', null, 30, null, 'Pipe', '{"Level": 42, "Strength": 90}'::jsonb, '{"Bonus": "Chakra Drain"}'::jsonb, 'Legendary', false),
  ('Armor Breaking Blade', 'arma', 'One of the 7 Legendary Swords of the Mist.', null, 55, null, 'Seven Blades', '{"Level": 35, "Strength": 80}'::jsonb, '{"Bonus": "3 tiles knockback", "Strength": "+5"}'::jsonb, 'Common', false),
  ('Decaptating Blade', 'arma', 'One of the 7 Legendary Swords of the Mist.', null, 55, null, 'Seven Blades', '{"Level": 35, "Strength": 80}'::jsonb, '{"Bonus": "1 Tile knockback, HP Healing", "Fortitude": "+4", "Strength": "+2"}'::jsonb, 'Common', false),
  ('Flameburst Blade', 'arma', 'One of the 7 Legendary Swords of the Mist.', null, 51, 3, 'Seven Blades', '{"Level": 35, "Strength": 80}'::jsonb, '{"Bonus": "Applies burn", "Fortitude": "+5", "Intellect": "+3"}'::jsonb, 'Common', false),
  ('Chakra Spear Blade', 'arma', 'One of the 7 Legendary Swords of the Mist.', null, 42, null, 'Seven Blades', '{"Level": 35, "Strength": 80}'::jsonb, '{"Bonus": "Jutsu cast", "Chakra": "+5", "Intellect": "+5"}'::jsonb, 'Common', false),
  ('Needle Blade', 'arma', 'One of the 7 Legendary Swords of the Mist.', null, 47, null, 'Seven Blades', '{"Level": 35, "Strength": 80}'::jsonb, '{"Bonus": "Jutsu cast", "Fortitude": "+10"}'::jsonb, 'Common', false),
  ('Scale Skin Blade', 'arma', 'One of the 7 Legendary Swords of the Mist.', null, 55, null, 'Seven Blades', '{"Level": 35, "Strength": 80}'::jsonb, '{"Chakra": "+15", "Chakra Steal": "25%", "Strength": "+3"}'::jsonb, 'Common', false),
  ('Thunder Blades', 'arma', 'One of the 7 Legendary Swords of the Mist.', null, 47, null, 'Seven Blades', '{"Level": 35, "Strength": 80}'::jsonb, '{"Bonus": "Jutsu cast", "Intellect": "+5"}'::jsonb, 'Common', false),
  ('Kazaruu', 'arma', 'Forged by fusing molten gold and obsidian onto a fallen blade, this dark scythe radiates heat. Each strike delivers a deadly slash that scorches flesh and shadow alike dealing 48 base damage and stealing enemies chakra.', null, 48, null, 'Sword', '{"Intellect": 45, "Level": 54, "Strength": 75}'::jsonb, '{"Chakra Steal": "10%", "Fortitude": "+1", "Intellect": "+2"}'::jsonb, 'Legendary', false),
  ('Kyuketsuki', 'arma', 'Made of the rarest crafting materials as crystal. When used as a sword, deals 56 damage on hits.', null, 56, null, 'Sword', '{"Level": 54, "Strength": 120}'::jsonb, '{"Agility": "+7", "Fortitude": "+1"}'::jsonb, 'Rare', false),
  ('Cursed Scythe', 'arma', 'A brutal, soul-touched weapon that strikes with 42 base damage, each swing echoing with lingering malice.', null, 42, 1, 'Sword', '{"Intellect": 25, "Level": 30, "Strength": 50}'::jsonb, '{"Chakra": "+2", "Intellect": "+2"}'::jsonb, 'Unique', false),
  ('Twin Blades', 'arma', 'Dual swords that deal 39 base damage with unique looks that can kick enemies almost miles away.', null, 39, null, 'Sword', '{"Level": 28, "Strength": 70}'::jsonb, '{"Bonus": "50% Knockback"}'::jsonb, 'Rare', false),
  ('Spiked Baseball Bat', 'arma', 'A spiked baseball bat that can be used in place of a Sword that adds 38 damage once wielded by sporty ninja.', null, 38, null, 'Sword', '{"Level": 25, "Strength": 70}'::jsonb, '{"Strength": "+2"}'::jsonb, 'Rare', false),
  ('Shirokata', 'arma', 'A well-forged katana that adds 39 damage and glows of white Chakra when used by ninjas. It''s glow is distinct and mysterious.', null, 39, null, 'Sword', '{"Level": 40, "Strength": 75}'::jsonb, '{"Chakra": "+2"}'::jsonb, 'Rare', false),
  ('Dark Bandit Blade', 'arma', 'A very crudely forged blade intended to sever limbs from the bodies of enemies. Deals 49 base damage.', null, 49, null, 'Sword', '{"Level": 40, "Strength": 100}'::jsonb, '{}'::jsonb, 'Unique', false),
  ('Blood Katana', 'arma', 'A blood-infused wooden katana that adds 59 base damage and scales your melee attacks with Strength.', null, 59, null, 'Sword', '{"Level": 51, "Strength": 110}'::jsonb, '{"Chakra": "+5", "Life Steal": "8%"}'::jsonb, 'Enchanted', false),
  ('Dark Scythes', 'arma', 'Two small dark scythes that works like a sword replacement. Adds 57 base damage and scales your melee attacks with Strength.', null, 57, null, 'Sword', '{"Level": 51, "Strength": 110}'::jsonb, '{"Strength": "+3"}'::jsonb, 'Legendary', false),
  ('Adamantine Claymore', 'arma', 'A large broad sword that seems like it was made for a person larger than life. Deals 80 on hit and knocking them back 2 tiles.', null, 72, null, 'Sword', '{"Level": 59, "Strength": 120}'::jsonb, '{"Bonus": "Knockback", "Fortitude": "+4", "Strength": "+2"}'::jsonb, 'Legendary', false),
  ('Asarihanma', 'arma', 'This hammer is made with a dense shell of a clam, it''s eye twitches from time to time... Can be used as a sword, dealing 68 on hit and knocking them back 4 tiles.', null, 68, null, 'Sword', '{"Level": 53, "Strength": 115}'::jsonb, '{"Bonus": "Knockback", "Chakra": "+2", "Fortitude": "+2", "Intellect": "+2", "Strength": "+2"}'::jsonb, 'Legendary', false),
  ('Hunter Warglaive', 'arma', 'Hunter warglaive that focuses on attacking multiple targets at once and adds 60 damage while making it user steal enemies life.', null, 60, null, 'Sword', '{"Level": 58, "Strength": 105}'::jsonb, '{"Bonus": "8 tile AOE around user", "Fortitude": "+3", "Life Steal": "5%"}'::jsonb, 'Legendary', false),
  ('Jakuma', 'arma', 'An unknown, black metal is used to craft this blade and even it''s hilt. When used as a sword, deals 65 damage on hits. Gives it''s wielder Chakra Regeneration passive.', null, 65, null, 'Sword', '{"Chakra": 40, "Level": 59, "Strength": 100}'::jsonb, '{"Bonus": "Chakra Regeneration", "Chakra": "+3"}'::jsonb, 'Legendary', false),
  ('Yamazaru', 'arma', 'An unknown, red metal is used to craft this blade and even it''s hilt. When used as a sword, deals 65 damage on hits. Gives it''s wielder Health Regeneration passive.', null, 65, null, 'Sword', '{"Level": 59, "Strength": 120}'::jsonb, '{"Bonus": "Health Regeneration", "Fortitude": "+3"}'::jsonb, 'Legendary', false),
  ('Wooden Katana', 'arma', 'A simple wooden katana that adds 16 base damage and scales your melee attacks with Strength.', null, 16, 1, 'Sword', '{"Level": 5, "Strength": 13}'::jsonb, '{}'::jsonb, 'Common', false),
  ('Broad Sword', 'arma', 'A broad sword crafted with a heavy metal alloy that adds 23 damage. Beating an enemy down with this will be easy, but requires a large amount of strength to utilize.', null, 23, 1, 'Sword', '{"Level": 10, "Strength": 23}'::jsonb, '{}'::jsonb, 'Common', false),
  ('Nikuya', 'arma', 'A large cleaver-like blade that adds 40 damage. It is broad with a fairly long hilt and has three hinges running along the blade.', null, 40, 1, 'Sword', '{"Level": 20, "Strength": 53}'::jsonb, '{}'::jsonb, 'Common', false),
  ('Butcher Sword', 'arma', 'A well-forged blade that glows radiantly with blue Chakra that adds 32 damage.', null, 32, 1, 'Sword', '{"Level": 15, "Strength": 30}'::jsonb, '{}'::jsonb, 'Common', false),
  ('Stylish Sword', 'arma', 'A Stylish Tsurigi that adds 36 damage once wielded by Stylish Ninja.', null, 36, 1, 'Sword', '{"Level": 25, "Strength": 70}'::jsonb, '{"Strength": "+2"}'::jsonb, 'Rare', false),
  ('Great Grandfather''s Muramasa', 'arma', 'You are truly blessed to witness the powers of this extravagant sword! Carved by once the Greatest Swordsman in the World, you must carry on his legacy and become a great warrior yourself!', null, 41, null, 'Sword', '{"Level": 30, "Strength": 80}'::jsonb, '{"Strength": "+1"}'::jsonb, 'Rare', false),
  ('Iron Scythe', 'arma', 'An iron scythe that works like a sword replacement. Adds 47 base damage and scales your melee attacks with Strength.', null, 47, null, 'Sword', '{"Level": 42, "Strength": 85}'::jsonb, '{"Strength": "+3"}'::jsonb, 'Rare', false),
  ('Religious Katana', 'arma', 'Katana that was once used by a religious group whom instead of its damage rate it for its light wealding and faster attack. Katana adds 36 damage.', null, 36, null, 'Sword', '{"Level": 40, "Strength": 70}'::jsonb, '{"Chakra": "+3"}'::jsonb, 'Rare', false),
  ('Kotsuzui Tanto', 'arma', 'This bone is compressed to maximum density, making it as solid as steel. A sharpened bone from a deadly ninja. When used as a sword, deals 47 damage on hits.', null, 47, null, 'Sword', '{"Level": 50, "Strength": 110}'::jsonb, '{}'::jsonb, 'Legendary', false)
on conflict (lower(name)) do update set
  type = excluded.type, description = excluded.description,
  base_damage = excluded.base_damage, attack_range = excluded.attack_range, weapon_group = excluded.weapon_group,
  weapon_requirements = excluded.weapon_requirements, weapon_buffs = excluded.weapon_buffs,
  weapon_rarity = excluded.weapon_rarity, weapon_agi_scaling = excluded.weapon_agi_scaling;

insert into jutsus (name, mastery_id, level_required, stat_req_stat, stat_req_value, base_damage, scaling) values
  ('Triple Phoenix Fireball', (select id from masteries where slug = 'fogo'), 10, 'int', 15, 37, 0.5),
  ('Big Flame Bullet', (select id from masteries where slug = 'fogo'), 15, 'int', 25, 50, 0.5),
  ('Fire Wall', (select id from masteries where slug = 'fogo'), 20, 'int', 35, 17, 0.5),
  ('Combusting Vortex', (select id from masteries where slug = 'fogo'), 25, 'int', 40, 49, 0.5),
  ('Great Fireball', (select id from masteries where slug = 'fogo'), 30, 'int', 50, 42, 0.5),
  ('Dragon Fire', (select id from masteries where slug = 'fogo'), 35, 'int', 65, 50, 0.5),
  ('Great Fire Strike', (select id from masteries where slug = 'fogo'), 70, 'int', 90, 0, 0.5),
  ('Triple Water Bullet', (select id from masteries where slug = 'agua'), 10, 'int', 15, 36, 0.5),
  ('Water Slash', (select id from masteries where slug = 'agua'), 15, 'int', 25, 42, 0.5),
  ('Colliding Wave', (select id from masteries where slug = 'agua'), 20, 'int', 35, 48, 0.5),
  ('Water Substitution', (select id from masteries where slug = 'agua'), 25, 'int', 40, 0, 0),
  ('Water Prison', (select id from masteries where slug = 'agua'), 30, 'int', 50, 25, 0.5),
  ('Great Water Shark', (select id from masteries where slug = 'agua'), 35, 'int', 60, 50, 0.5),
  ('Great Soap Bubble', (select id from masteries where slug = 'agua'), 10, 'str', 15, 28, 0.5),
  ('Bubble Solution Spitting', (select id from masteries where slug = 'agua'), 15, 'str', 25, 35, 0.5),
  ('Bubble Spray', (select id from masteries where slug = 'agua'), 20, 'str', 35, 43, 0.5),
  ('Bubble Clone', (select id from masteries where slug = 'agua'), 25, 'str', 40, 0, 0),
  ('Soap Explosion', (select id from masteries where slug = 'agua'), 30, 'str', 50, 33, 0.5),
  ('Great Bubble Shark', (select id from masteries where slug = 'agua'), 35, 'str', 60, 13, 0.5),
  ('Great Colliding Wave', (select id from masteries where slug = 'agua'), 70, 'int', 90, 38, 0.5),
  ('Bubble Coat', (select id from masteries where slug = 'agua'), 70, 'str', 90, 0, 0),
  ('Wind Shuriken', (select id from masteries where slug = 'vento'), 10, 'int', 15, 43, 0.5),
  ('Wind Scythe', (select id from masteries where slug = 'vento'), 15, 'int', 25, 43, 0.5),
  ('Drilling Air Bullet', (select id from masteries where slug = 'vento'), 20, 'int', 35, 50, 0.5),
  ('Hurricane Blade', (select id from masteries where slug = 'vento'), 25, 'int', 40, 47, 0.5),
  ('Vacuum Sphere', (select id from masteries where slug = 'vento'), 30, 'int', 50, 17, 0.5),
  ('Wind Claw', (select id from masteries where slug = 'vento'), 35, 'int', 60, 58, 0.5),
  ('Slashing Tornadoes', (select id from masteries where slug = 'vento'), 10, 'str', 15, 31, 0.41),
  ('Task of the Dragon', (select id from masteries where slug = 'vento'), 15, 'str', 25, 24, 0.41),
  ('Slicing Wind', (select id from masteries where slug = 'vento'), 20, 'str', 35, 35, 0.41),
  ('Wind Mask', (select id from masteries where slug = 'vento'), 25, 'str', 40, 1, 0),
  ('Wind Barrage', (select id from masteries where slug = 'vento'), 30, 'str', 50, 41, 0.41),
  ('Wind Cyclone', (select id from masteries where slug = 'vento'), 35, 'str', 60, 52, 0.41),
  ('Spiralling Shuriken', (select id from masteries where slug = 'vento'), 70, 'int', 90, 56, 0.5),
  ('Vacuum Slash', (select id from masteries where slug = 'vento'), 70, 'str', 90, 43, 0.41),
  ('Earth Pillar', (select id from masteries where slug = 'terra'), 10, 'int', 15, 30, 0.5),
  ('Great Earth Prison', (select id from masteries where slug = 'terra'), 15, 'int', 25, 16, 0.5),
  ('Earth Split', (select id from masteries where slug = 'terra'), 20, 'int', 35, 44, 0.5),
  ('Ravaging Earth Spikes', (select id from masteries where slug = 'terra'), 25, 'int', 40, 55, 0.5),
  ('Mud River', (select id from masteries where slug = 'terra'), 30, 'int', 50, 45, 0.5),
  ('Earth Wall', (select id from masteries where slug = 'terra'), 35, 'int', 60, 0, 0),
  ('Mud Pull', (select id from masteries where slug = 'terra'), 70, 'int', 90, 16, 0.5),
  ('Lightning Senbon', (select id from masteries where slug = 'raio'), 10, 'int', 15, 36, 0.5),
  ('Lightning Spear', (select id from masteries where slug = 'raio'), 15, 'int', 25, 43, 0.5),
  ('Advanced Lightning Cutter', (select id from masteries where slug = 'raio'), 20, 'int', 40, 52, 0.5),
  ('Feast of Lightning', (select id from masteries where slug = 'raio'), 25, 'int', 45, 49, 0.5),
  ('Lightning Current', (select id from masteries where slug = 'raio'), 30, 'int', 60, 33, 0.5),
  ('Binding Pillars', (select id from masteries where slug = 'raio'), 35, 'int', 65, 59, 0.5),
  ('Lightning Beast Fang', (select id from masteries where slug = 'raio'), 70, 'int', 90, 34, 0.5),
  ('Pressure Point Needle', (select id from masteries where slug = 'taijutsu'), 10, 'str', 15, 0, 0),
  ('Palm Bottom', (select id from masteries where slug = 'taijutsu'), 15, 'str', 25, 43, 0.5),
  ('Vacuum Palm', (select id from masteries where slug = 'taijutsu'), 20, 'str', 35, 38, 0.5),
  ('Mountain Crusher', (select id from masteries where slug = 'taijutsu'), 25, 'str', 40, 46, 0.5),
  ('Revolving Heavens', (select id from masteries where slug = 'taijutsu'), 30, 'str', 50, 60, 0.5),
  ('16 Palms', (select id from masteries where slug = 'taijutsu'), 35, 'str', 60, 45, 0.5),
  ('Seismic Dash', (select id from masteries where slug = 'taijutsu'), 10, 'agi', 15, 33, 0.5),
  ('Breaking Kick', (select id from masteries where slug = 'taijutsu'), 15, 'agi', 25, 38, 0.5),
  ('Speed Mirage', (select id from masteries where slug = 'taijutsu'), 20, 'agi', 35, 0, 0),
  ('Youthful Spring', (select id from masteries where slug = 'taijutsu'), 25, 'agi', 60, 0, 0),
  ('Morning Peacock', (select id from masteries where slug = 'taijutsu'), 30, 'agi', 50, 56, 0.5),
  ('Whirlwind Kick', (select id from masteries where slug = 'taijutsu'), 35, 'agi', 60, 50, 0.5),
  ('Spinning Lotus', (select id from masteries where slug = 'taijutsu'), 70, 'agi', 90, 21, 0.5),
  ('64 Palms', (select id from masteries where slug = 'taijutsu'), 70, 'str', 90, 45, 0.5),
  ('Treat Wounds', (select id from masteries where slug = 'medicina'), 10, 'cha', 10, 19, 0.56),
  ('Chakra Scalpel', (select id from masteries where slug = 'medicina'), 15, 'cha', 35, 0, 0),
  ('Mystical Palm', (select id from masteries where slug = 'medicina'), 20, 'cha', 35, 0, 0),
  ('Cell Regeneration', (select id from masteries where slug = 'medicina'), 30, 'cha', 60, 9, 0.56),
  ('Chakra Transfer', (select id from masteries where slug = 'medicina'), 35, 'cha', 65, 220, 0),
  ('Poison Senbon', (select id from masteries where slug = 'medicina'), 10, 'int', 10, 33, 0.5),
  ('Poison Scalpel', (select id from masteries where slug = 'medicina'), 15, 'int', 25, 42, 0.5),
  ('Antibodies Activation', (select id from masteries where slug = 'medicina'), 20, 'int', 35, 0, 0),
  ('Poison Cloud', (select id from masteries where slug = 'medicina'), 25, 'int', 40, 39, 0.5),
  ('Sticky Venom', (select id from masteries where slug = 'medicina'), 30, 'int', 50, 14, 0.5),
  ('Cursed Seal Activation', (select id from masteries where slug = 'medicina'), 35, 'int', 65, 0, 0),
  ('Mending Seal', (select id from masteries where slug = 'medicina'), 70, 'cha', 120, 9, 0.56),
  ('Poisonous Shroud', (select id from masteries where slug = 'medicina'), 70, 'int', 90, 25, 0.5),
  ('Great Explosive Kunai', (select id from masteries where slug = 'arma'), 10, 'int', 15, 34, 0.5),
  ('Shockwave Slash', (select id from masteries where slug = 'arma'), 10, 'str', 15, 35, 0.5),
  ('Triple Explosive Tag', (select id from masteries where slug = 'arma'), 15, 'int', 25, 38, 0.5),
  ('Risky Blade Dance', (select id from masteries where slug = 'arma'), 15, 'str', 25, 29, 0.5),
  ('Shadow Shuriken', (select id from masteries where slug = 'arma'), 20, 'int', 35, 34, 0.5),
  ('Blade Piercing', (select id from masteries where slug = 'arma'), 20, 'str', 35, 32, 0.5),
  ('Hidden Explosive Tag', (select id from masteries where slug = 'arma'), 25, 'int', 40, 39, 0.5),
  ('Wild Slashes', (select id from masteries where slug = 'arma'), 25, 'str', 40, 30, 0.5),
  ('Exploding Spiked Ball', (select id from masteries where slug = 'arma'), 30, 'int', 50, 48, 0.5),
  ('Crescent Moon Beheading', (select id from masteries where slug = 'arma'), 30, 'str', 50, 1, 0.5),
  ('Bear Trap', (select id from masteries where slug = 'arma'), 35, 'int', 60, 26, 0.5),
  ('Dance of the Crescent Moon', (select id from masteries where slug = 'arma'), 35, 'str', 60, 31, 0.5),
  ('Summoning Tool Scroll', (select id from masteries where slug = 'arma'), 70, 'int', 90, 26, 0.5),
  ('Blade Fury', (select id from masteries where slug = 'arma'), 70, 'str', 90, 31, 0.5)
on conflict (mastery_id, name) do update set
  level_required = excluded.level_required, stat_req_stat = excluded.stat_req_stat,
  stat_req_value = excluded.stat_req_value, base_damage = excluded.base_damage, scaling = excluded.scaling;

-- ---------------------------------------------------------------
-- Missões Diárias (seed a partir de ninonline.fandom.com/wiki/Missions)
-- ---------------------------------------------------------------
-- Índice único que trata "mesma missão, vilas diferentes" como linhas
-- distintas, mas evita duplicar a mesma missão+vila se essa seção
-- rodar de novo.
create unique index if not exists missions_name_village_unique_idx
  on missions (name, coalesce(village_id, ''));

insert into missions (name, description, mission_type, rank, village_id, xp, ryo, level_min, level_max, objectives) values
  ('Messenger Ninja', 'Collect and Deliver the message scroll', 'diaria', 'D', null, 0, 0, null, null, '[]'::jsonb),
  ('Mission Assignments (Sand)', 'Ask Midori at the Mission Assignment Desk for Information.', 'diaria', 'D', 'areia', 25, 0, null, null, '[]'::jsonb),
  ('Bad Larva', 'Kill 80 Larvae (0/80)', 'diaria', 'D', null, 180, 40, null, null, '[{"item": "Larvae", "quantity": 80}]'::jsonb),
  ('Mission Assignments (Leaf)', null, 'diaria', 'D', 'folha', 25, 0, null, null, '[]'::jsonb),
  ('Take out the Trash', 'Remove 7 Trash Bags (0/7) (Take out the Trash I)', 'diaria', 'D', null, 150, 50, null, null, '[{"item": "Trash Bags", "quantity": 7}]'::jsonb),
  ('Defeat Spiders', 'Kill 90 Spiderlings (0/90)', 'diaria', 'D', null, 260, 55, null, null, '[{"item": "Spiderlings", "quantity": 90}]'::jsonb),
  ('Mission: Mutant Rats', 'Kill 70 Mutant Rats (0/70)', 'diaria', 'C', null, 8600, 140, null, null, '[{"item": "Mutant Rats", "quantity": 70}]'::jsonb),
  ('Lost Puppy "Giba"', 'Ask Norito about his missing puppy; follow his tip to find "Giba"', 'diaria', 'D', null, 3240, 120, null, null, '[]'::jsonb),
  ('Bear Hunt', 'Kill 70 Brown Bears (0/70)', 'diaria', 'C', null, 30000, 200, null, null, '[{"item": "Brown Bears", "quantity": 70}]'::jsonb),
  ('Coyote Hunting', 'Kill 80 Coyotes (0/80)', 'diaria', 'D', null, 2020, 90, null, null, '[{"item": "Coyotes", "quantity": 80}]'::jsonb),
  ('Academy Scrolls', 'Help Sensei make Ninjutsu Scrolls: 1 Body Flicker Manual (Leaf) / 1 Cloak of Invisibility Manual (Sand) / 1 Substitution Manual (Mist)', 'diaria', 'D', null, 5820, 80, null, null, '[]'::jsonb),
  ('Horned Beasts', 'Kill 90 Boars (0/90) — nível 1; Kill 50 Black Boars (0/50) — nível 2', 'diaria', 'C', null, 3100, 100, null, null, '[{"item": "Boars", "quantity": 90}, {"item": "Black Boars", "quantity": 50}]'::jsonb),
  ('Moist Sand Beasts', 'Kill 35 Tunneler (0/35)', 'diaria', 'C', null, 4700, 100, null, null, '[{"item": "Tunneler", "quantity": 35}]'::jsonb),
  ('Twin Sister Delivery', null, 'diaria', 'C', null, 17400, 140, null, null, '[]'::jsonb),
  ('Mission Assignments (Mist)', null, 'diaria', 'D', 'neblina', 25, 0, null, null, '[]'::jsonb),
  ('Time Off', 'Relax at the Leaf Village Hotsprings (0/900)', 'diaria', 'D', null, 3500, 0, null, null, '[]'::jsonb),
  ('Wolf Hunting', 'Kill 80 Wolves (0/80)', 'diaria', 'D', null, 2020, 90, null, null, '[{"item": "Wolves", "quantity": 80}]'::jsonb),
  ('Big Ancient Insects', 'Kill 70 Big Scarabs (0/70)', 'diaria', 'C', null, 14600, 140, null, null, '[{"item": "Big Scarabs", "quantity": 70}]'::jsonb),
  ('Eastward Shipment', 'Find Etsuko to take the shipment, then bring it to Gobori.', 'diaria', 'C', null, 22240, 140, null, null, '[]'::jsonb),
  ('Sand Style Relaxation', 'Relax at the Sand Village Spa (0/900)', 'diaria', 'D', null, 0, 0, null, null, '[]'::jsonb),
  ('Endanger Tigers', null, 'diaria', 'C', null, 3100, 100, null, null, '[]'::jsonb),
  ('Danger Dangos', 'Buy Danger Dango and give it to Itori.', 'diaria', 'D', null, 3200, 90, null, null, '[]'::jsonb),
  ('The Exorcist', null, 'diaria', 'C', null, 14600, 140, null, null, '[]'::jsonb),
  ('Giant Fire Ant Infestation', 'Kill 40 Giant Fire Ants (Bloody Pond / Ant Tunnel, west of Bamboo Forest)', 'diaria', 'C', null, 18000, 0, null, null, '[{"item": "Giant Fire Ants", "quantity": 40}]'::jsonb),
  ('Medicine Supplies I', 'Leaf: 30 Cocoon e 30 Spider Eggs (só a variante Leaf documentada)', 'diaria', 'D', null, 0, 0, null, null, '[]'::jsonb),
  ('Shark Attack', 'Kill 25 Great White Sharks (0/25)', 'diaria', 'C', null, 228390, 160, 46, 53, '[{"item": "Great White Sharks", "quantity": 25}]'::jsonb),
  ('Medicine Supplies II', 'Fale com o Herbalista da vila (Sand: Masumi) e reúna os ingredientes pedidos.', 'diaria', 'D', null, 0, 0, null, null, '[]'::jsonb),
  ('Clear the Abandoned Lair', null, 'diaria', 'C', null, 46500, 145, 25, 35, '[]'::jsonb),
  ('Clear the Abandoned Lair II', null, 'diaria', 'C', null, 59040, 160, 27, 38, '[]'::jsonb),
  ('The Wolf Pack', 'Kill Snow Wolf (60), Kill Alpha Wolf (10), Obtain Wolf Fur (10)', 'diaria', 'C', null, 78600, 0, null, null, '[]'::jsonb),
  ('Guilty Pleasure Mist Style', 'Sneak into the Mist Village Spa (0/300)', 'diaria', 'B', null, 75000, 0, null, null, '[]'::jsonb),
  ('Village''s Most Wanted', 'Collect 75 Ryo from the Bounty Station (nível 1); Collect 100 Ryo (nível 2)', 'diaria', 'S', null, 200000, 0, null, null, '[]'::jsonb),
  ('Village Entrance Guard Duty', 'Stand Guard at the Village Entrance without fainting (0/600, 10 min)', 'diaria', 'B', null, 46500, 300, null, null, '[]'::jsonb),
  ('Medical Supplies', 'Missão em camadas (Tier I C 9.100xp/100ryo, Tier II B 78.100xp/175ryo, Tier III A 223.300xp/270ryo)', 'diaria', 'C', null, 9100, 100, null, null, '[]'::jsonb),
  ('Retrieve Compromised Documents', null, 'diaria', 'A', null, 149985, 200, null, null, '[]'::jsonb),
  ('Waging War', '(I) 40.900xp/30ryo · (II) 65.810xp/35ryo · (III) 99.150xp/55ryo · (IV) 151.125xp/105ryo', 'diaria', 'B', null, 40900, 30, 21, 30, '[]'::jsonb),
  ('Puppet Retirement', 'Kill 40 Blood Puppets (0/40); Kill 20 Old Blood Puppets (0/20)', 'diaria', 'A', null, 166820, 185, null, null, '[{"item": "Blood Puppets", "quantity": 40}, {"item": "Old Blood Puppets", "quantity": 20}]'::jsonb),
  ('Bounty Hunting', '(I) 46.500xp · (II) 81.800xp · (III) 131.600xp · (IV) 178.400xp', 'diaria', 'B', null, 46500, 0, 21, 30, '[]'::jsonb),
  ('Spy on Hokage/Kazekage/Mizukage Office', 'Infiltrate the opposing village''s office for 2 minutes without fainting (0/120)', 'diaria', 'A', null, 107362, 265, 30, 40, '[]'::jsonb),
  ('Survey Leaf/Sand/Mist Village Entrance', 'Survey the opposing village entrance for 2 minutes without fainting (0/120)', 'diaria', 'A', null, 93040, 180, null, null, '[]'::jsonb),
  ('Cold-Blooded Killer', 'Missão em 8 tiers; valores mostrados são do tier VIII (nível 61+)', 'diaria', 'B', null, 327410, 0, 61, null, '[]'::jsonb),
  ('Glacier Bear Hunt', 'Kill 1 the Glacier Bear (0/1)', 'diaria', 'A', null, 41000, 350, null, null, '[]'::jsonb),
  ('Guilty Pleasure', 'Sneak into the Leaf Village Hotsprings (0/300)', 'diaria', 'B', null, 46400, 0, 19, 50, '[]'::jsonb),
  ('Medicine Supplies IV', 'Help Medicine Shop restock medicinal ingredients (lista exata só aparece falando com Himura)', 'diaria', 'A', null, 342640, 200, 58, 70, '[]'::jsonb),
  ('Takumi Watch', 'Survey Takumi Village for enemy ninja activity; eliminate hostile threats and report back', 'diaria', 'S', null, 318400, 250, 57, 70, '[]'::jsonb),
  ('Village''s Most Wanted III', 'Kill enemy ninjas listed in Bingo Book "B"; collect their reward at the Bounty Station', 'diaria', 'S', null, 343600, 0, 57, 70, '[]'::jsonb),
  ('Leaf Village Assault', 'Eliminate Leaf Village Jonin', 'diaria', 'S', null, 310200, 200, 59, null, '[]'::jsonb),
  ('Silent Shipment', 'Obtain 1 Supply Package (0/1) — cuidado, ele cai se você morrer carregando', 'diaria', 'S', null, 264730, 200, 51, null, '[{"item": "Supply Package", "quantity": 1}]'::jsonb),
  ('Escort the Foreign Envoy', 'Escort Envoy to <destination> Village (0/1) — a missão falha se você ou o escoltado desmaiar', 'diaria', 'S', null, 391250, 150, 50, null, '[]'::jsonb),
  ('Mist Village Assault', 'Eliminate Mist Village Jonin', 'diaria', 'S', null, 310200, 200, 59, null, '[]'::jsonb),
  ('The Sandstorm Predator', 'Hunt the Dark Weasel (contagem exata não registrada)', 'diaria', 'S', null, 461210, 300, 65, null, '[]'::jsonb),
  ('Dethrone the Beast', 'Kill Dark Monkey King (0/1)', 'diaria', 'S', null, 461370, 300, null, null, '[]'::jsonb),
  ('Bad Commuters', 'Objetivo não registrado no wiki — provavelmente os "train gangsters" da descrição', 'diaria', 'B', null, 0, 0, null, null, '[]'::jsonb),
  ('Open for Business', null, 'diaria', 'A', null, 69750, 30, 25, 30, '[]'::jsonb),
  ('Bandit Hunt I', 'Kill Takeshi (1), Kill Kariyuse (1), Kill Tause (1), Obtain Blood Vial (10) — repetível, Bandit Questline', 'diaria', 'B', null, 74200, 0, 44, null, '[]'::jsonb),
  ('Bandit Hunt II', 'Kill Kiemon (1), Kill Hasuka (1), Kill Nelinel (1), Kill Torii (1), Obtain Blood Vial (15) — repetível, Bandit Questline', 'diaria', 'B', null, 79700, 0, 44, null, '[]'::jsonb),
  ('Your Best Behavior', 'Reflita sobre seus crimes: passe 600s na Prisão Principal ou Enfermaria; volte ao Warden Haoya. Repetível, Hyoketsu Prison, reduz Crime em 2', 'diaria', 'B', null, 0, 0, 1, null, '[]'::jsonb),
  ('Prison Work', 'Entregar ao Warden Haoya: Copper Ore (20), Coal Ore (10), Iridescent Weeds (10). Repetível, Hyoketsu Prison, reduz Crime em 4', 'diaria', 'B', null, 0, 0, 10, null, '[]'::jsonb),
  ('Bat Clearance', 'Kill Bats (50); Turn in Bat Wing (10). Repetível, Hyoketsu Prison, reduz Crime em 4', 'diaria', 'B', null, 0, 0, 20, null, '[]'::jsonb),
  ('Fox Hunting', 'Sem página própria no wiki até o momento.', 'diaria', 'D', null, 0, 0, null, null, '[]'::jsonb),
  ('Antidotes Creation', 'Sem página própria no wiki até o momento.', 'diaria', 'C', null, 0, 0, null, null, '[]'::jsonb),
  ('Giant Ant Infestation', 'Sem página própria no wiki até o momento.', 'diaria', 'C', null, 0, 0, null, null, '[]'::jsonb),
  ('Medicine Supplies III', 'Sem página própria no wiki até o momento — parte da série Medicine Supplies (Tier III).', 'diaria', 'B', null, 0, 0, null, null, '[]'::jsonb)
on conflict (name, coalesce(village_id, '')) do update set
  description = excluded.description,
  rank = excluded.rank,
  xp = excluded.xp,
  ryo = excluded.ryo,
  level_min = excluded.level_min,
  level_max = excluded.level_max,
  objectives = excluded.objectives;

-- ---------------------------------------------------------------
-- Seed: Mobs (migração 011, a partir do ninonline.fandom.com/wiki/Category:Mob)
-- ---------------------------------------------------------------
-- Migração 011: cadastro dos Mobs (monstros) do jogo, extraídos de
-- https://ninonline.fandom.com/wiki/Category:Mob (categoria completa, 145
-- páginas de mob individuais — a lista "147" da categoria inclui a própria
-- página-índice "Mob" e uma categoria-filha, que não são mobs em si).
--
-- Escopo, conforme pedido: TODOS os mobs da wiki, incluindo os drops de
-- cada um, e criando automaticamente na tabela `items` os itens de drop
-- que ainda não existem no catálogo (type = 'item_mob').
--
-- Fonte dos dados: infobox {{Infobox/Monster|...}} de cada página (level,
-- health, location, damage, type, experience, special_ability, drops) e,
-- quando presente, a tabela "Loot List" da página (mais precisa que o
-- campo de texto livre `drops` do infobox).
--
-- Classificação (`category`):
--   - 'boss': mobs listados nas categorias Category:BOSS / Category:Boss
--     da wiki, OU cujo campo `type` do infobox contém a palavra "Boss"
--     (ex.: "Yokai (Boss)" pra Ongaku, Kikkumaru, Jirou).
--   - 'enfurecido': mobs cujo nome começa com "Angry", "Enraged" ou "Mad"
--     (não existe categoria própria na wiki pra isso, então foi um
--     heurística por nome).
--   - 'regular': todo o resto.
--
-- Lacunas de dados: ~26 mobs não têm infobox completo na própria wiki
-- (páginas-stub, principalmente "Elite" da seção de Bestiário/mobs raros
-- e alguns "Not recorded"/"Information needed"). Pra esses, `level` e
-- `hp` caem no default da coluna (1) em vez de ficar null, já que as
-- colunas são NOT NULL — edite manualmente no Admin quando o dado
-- correto for descoberto/confirmado no jogo.
--
-- Imagens (`image_url`) ficam propositalmente null — conforme combinado,
-- o upload das imagens de mob é manual, feito depois pelo admin.
--
-- Itens de drop criados automaticamente (tabela items, type='item_mob')
-- não têm descrição nem imagem — preencha depois no Admin. O
-- "on conflict (lower(name)) do nothing" abaixo garante que reexecutar
-- essa migração nunca sobrescreve um item que você já editou manualmente
-- (nome, descrição, imagem, ou mesmo um type diferente que você tenha
-- corrigido).
--
-- Taxas de drop (`drop_rate`): quando a página tem uma "Loot List"
-- estruturada, o percentual vem direto dela. Quando só há o campo de
-- texto livre (ex.: "Common", "<5%", "Rare"), foi convertido por uma
-- tabela aproximada (Common=50%, Uncommon=20%, Rare=5%, "<1%"=0.5%,
-- "<5%"=3%); quando não dá pra inferir nada, `drop_rate` fica null.

create unique index if not exists mobs_name_unique_idx on mobs (lower(name));

-- ---------------------------------------------------------------
-- Itens de drop (cria os que faltam no catálogo)
-- ---------------------------------------------------------------
insert into items (name, type) values
  ('Adamantine Staff', 'item_mob'),
  ('Adamantine Sword', 'item_mob'),
  ('Ant Feelers', 'item_mob'),
  ('Arm Bandage', 'item_mob'),
  ('Asarihanma', 'item_mob'),
  ('Bamboo Hat', 'item_mob'),
  ('Bat Wings', 'item_mob'),
  ('Beaded Necklace', 'item_mob'),
  ('Bear Paw', 'item_mob'),
  ('Big Scarab Shell', 'item_mob'),
  ('Big Scarab Shells', 'item_mob'),
  ('Black Arm Bandages', 'item_mob'),
  ('Black Backpack', 'item_mob'),
  ('Black Bandit Blade', 'item_mob'),
  ('Black Bandit Mask', 'item_mob'),
  ('Black Bandit Pants', 'item_mob'),
  ('Black Bandit Shoes', 'item_mob'),
  ('Black Bear Hood', 'item_mob'),
  ('Black Bear Paws', 'item_mob'),
  ('Black Folded Pants', 'item_mob'),
  ('Black Giant Folding Fan', 'item_mob'),
  ('Black Masked Top', 'item_mob'),
  ('Blank Scroll', 'item_mob'),
  ('Blank Scroll.', 'item_mob'),
  ('Blank Scrolls', 'item_mob'),
  ('Blood Engine', 'item_mob'),
  ('Blood Iron Fan', 'item_mob'),
  ('Blood Vial', 'item_mob'),
  ('Blue Bandit Mask', 'item_mob'),
  ('Blue Folded Pants', 'item_mob'),
  ('Blue Masked Top', 'item_mob'),
  ('Boar Tusk', 'item_mob'),
  ('Brownbear Paws', 'item_mob'),
  ('Canine Fang', 'item_mob'),
  ('Carrot', 'item_mob'),
  ('Chest Bandages', 'item_mob'),
  ('Cocoon', 'item_mob'),
  ('Crystal Fan', 'item_mob'),
  ('Crystal Pipe', 'item_mob'),
  ('Dark Barbarian Cloak Recipe', 'item_mob'),
  ('Dark Fur', 'item_mob'),
  ('Dark Scythes', 'item_mob'),
  ('Dark Veiled Sakkat Recipe', 'item_mob'),
  ('Demon Claws', 'item_mob'),
  ('DNA Sample', 'item_mob'),
  ('Double Arm Bandages', 'item_mob'),
  ('Dragonfly wings', 'item_mob'),
  ('Egg', 'item_mob'),
  ('Eggs', 'item_mob'),
  ('Finger', 'item_mob'),
  ('Fox Fur', 'item_mob'),
  ('Gas Mask', 'item_mob'),
  ('Gloves Knuckle', 'item_mob'),
  ('Gray Bear Paw', 'item_mob'),
  ('Great Grandfather''s Muramasa', 'item_mob'),
  ('Green Folded Pants', 'item_mob'),
  ('Green Striped Bucket Hat', 'item_mob'),
  ('Hanging Sakkat', 'item_mob'),
  ('Hawk Feather', 'item_mob'),
  ('Hawk Talon', 'item_mob'),
  ('Hohuto Sphere II', 'item_mob'),
  ('Hokuto Sphere I', 'item_mob'),
  ('Hokuto Sphere II', 'item_mob'),
  ('Hokuto Sphere IV', 'item_mob'),
  ('Hokutso Sphere III', 'item_mob'),
  ('Honey Comb', 'item_mob'),
  ('Hunters Warglaive', 'item_mob'),
  ('Insect Wing', 'item_mob'),
  ('Insect Wings', 'item_mob'),
  ('Iron Piece', 'item_mob'),
  ('Iron Prison Key', 'item_mob'),
  ('Iron Scythe', 'item_mob'),
  ('Jakuma', 'item_mob'),
  ('Kazaruu Recipe', 'item_mob'),
  ('Kotsuzui Tanto', 'item_mob'),
  ('Large Scarab Pincers', 'item_mob'),
  ('Leather', 'item_mob'),
  ('Leech Fang', 'item_mob'),
  ('Leech Shell', 'item_mob'),
  ('Leg Bandage', 'item_mob'),
  ('Mizukane?', 'item_mob'),
  ('Mobster Ring', 'item_mob'),
  ('Moth Wings', 'item_mob'),
  ('Nitoryu Recipe', 'item_mob'),
  ('Old Tengu Mask', 'item_mob'),
  ('Orange Striped Bucket Hat', 'item_mob'),
  ('Oriental Fan', 'item_mob'),
  ('Penguin Beak', 'item_mob'),
  ('Prowler Pants', 'item_mob'),
  ('Puppet head', 'item_mob'),
  ('Puppet limb', 'item_mob'),
  ('Puppet string', 'item_mob'),
  ('Rabbit Paw', 'item_mob'),
  ('Rabid Hide', 'item_mob'),
  ('Raccoon Tail', 'item_mob'),
  ('Raging Bandit Pants', 'item_mob'),
  ('Raging Hermit Pants', 'item_mob'),
  ('Raging Hermit Shirt', 'item_mob'),
  ('Random Tools Pack', 'item_mob'),
  ('Rat Tail', 'item_mob'),
  ('Red Backpack', 'item_mob'),
  ('Red Fighter Pants', 'item_mob'),
  ('Red Folded Pants', 'item_mob'),
  ('Red Poncho', 'item_mob'),
  ('Red Scarf', 'item_mob'),
  ('Red Striped Bucket Hat', 'item_mob'),
  ('Red Twinfall Scarf Recipe', 'item_mob'),
  ('Reinforced Bo Staff', 'item_mob'),
  ('Religious Katana', 'item_mob'),
  ('Romaji Bandit Pants', 'item_mob'),
  ('Sashed Baggy Pants', 'item_mob'),
  ('Scarab Shell', 'item_mob'),
  ('Scorpion Tail', 'item_mob'),
  ('Seathorn Pipe', 'item_mob'),
  ('See the Drops table below', 'item_mob'),
  ('Seji no Hani', 'item_mob'),
  ('Shirokata', 'item_mob'),
  ('Silk', 'item_mob'),
  ('Snake Belt', 'item_mob'),
  ('Snake Inner Kimono', 'item_mob'),
  ('Snake Rope Belt', 'item_mob'),
  ('Snake Venom', 'item_mob'),
  ('Spider Eggs', 'item_mob'),
  ('Straw Hat', 'item_mob'),
  ('Sukarabe Omo', 'item_mob'),
  ('Tales of a Gutsy Ninja', 'item_mob'),
  ('Tan Barbarian Cloak Recipe', 'item_mob'),
  ('Tanned Leather', 'item_mob'),
  ('Teeth', 'item_mob'),
  ('Tengai Hat', 'item_mob'),
  ('Tengu Mask', 'item_mob'),
  ('Tiger Fur', 'item_mob'),
  ('Tonfa', 'item_mob'),
  ('Tunneler Tongue', 'item_mob'),
  ('Twin Blades', 'item_mob'),
  ('Twin Fangs', 'item_mob'),
  ('Undead Charm', 'item_mob'),
  ('Venom', 'item_mob'),
  ('Vigilante Bandana Mask Recipe', 'item_mob'),
  ('White Bandit Mask', 'item_mob'),
  ('White Fighter Pants', 'item_mob'),
  ('White Folded Pants', 'item_mob'),
  ('White Straw Hat', 'item_mob'),
  ('Whiter Fighter Pants', 'item_mob'),
  ('Winter Scarf', 'item_mob'),
  ('Wolf Fur', 'item_mob'),
  ('Wooden Tonfa', 'item_mob'),
  ('Yamazaru', 'item_mob')
on conflict (lower(name)) do nothing;

-- ---------------------------------------------------------------
-- Mobs
-- ---------------------------------------------------------------
insert into mobs (name, category, level, location_note, hp, damage_min, damage_max, combat_type, xp_reward, description, special_abilities) values
  ('Big Scarabs', 'regular', 23, 'Secret Desert Cavern', 155, 39, 39, 'agressivo', 172, 'Big Scarabs are a Level 23 mobs which currently inhabit various locations around the Sand Village, most notably Secret Desert Cavern.
* Attacks (moves) they are using:
** Basic Attack - 39 physical damage
It has been noted that it is a aggresive-type monster that will attack and follow you once you get in it''s range. Upon defeating this Monster, you receive 172xp (258 blessing).', '{}'),
  ('Bear', 'regular', 36, 'South of Leaf Village', 300, 94, 94, 'agressivo', 266, 'Bears are a Level 36 mob which currently inhabit various locations around the Leaf Village, most notably on the south of the village They are attributed really high damage and health but they are slow, because of this you can easily get past them or kill them by kiting around  them.', '{"Mountain Crash"}'),
  ('Alpha Wolf', 'regular', 43, 'Lake Stasis - Snowy Path', 1100, 97, 97, 'agressivo', 436, 'Alpha Wolfs  possess status affects attributed to their physical attacks, this status effect is "Bleed I "
it deals 2 dmg for 20 second.', '{"Bite","Body Flicker"}'),
  ('Cursed Host', 'regular', 38, 'Cursed Caves', 38, 38, 38, 'agressivo', 38, 'Cursed Host are level 40 and 38 monsters that currently inhabit Rocky Caves map (Danger Zone).', '{"Body Flicker"}'),
  ('Bee', 'regular', 26, 'Maps near Takumi village and Kinsen Quarters', 155, 44, 44, 'passivo', 200, 'Bee is Level 26 monster which currently inhabit areas near the Takumi village and Kinsen Quarters or near Akatsuki Base', '{}'),
  ('Bee Hive', 'regular', 26, 'Near Tanzaku Quarters and Takumi village.', 500, 5, 5, 'passivo', 8, 'Bee Hive is an special monster which can''t move and deals 5 dmg to attackers.It has 100% chance to drop honey comb.', '{"Can''t move"}'),
  ('Chei', 'boss', 47, 'Lake Stasis', 3480, 99, 99, 'agressivo', 3200, 'Chei is Reain''s bodyguard who is a master of Taijutsu. Her jutsus perfectly match with Reain''s skills because she uses specific skills that stun the opponent. Which allows Reain to calmly eliminate uninvited guest.', '{"Ground Shattering Kick","Great Fireball","Body Flicker ( 21 tiles distance )","Whirlwind Kick","Breaking Kick","Substitution Technique"}'),
  ('Blood Puppet', 'regular', 51, 'Blood Puppet Factory', 1200, 245, 245, 'passivo', 0, 'A humanoid puppet monster with mind of it''s own.', '{}'),
  ('Ant', 'regular', 3, '3 Way Road Split/Bloody Pond', 20, 7, 7, 'passivo', 20, 'Ants are Level 5 monsters which currently inhabit various locations around the Mist village, most notably on 3 Way Road Split and Bloody Pond.', '{}'),
  ('Boar', 'regular', 13, 'Misty Hides / Land of Water Port', 85, 26, 26, 'agressivo', 97, 'Boars are a level 13 monster which lives in an area close to the Mist Village called Misty Hides and also at the Land of Water Port.', '{}'),
  ('Black Boar', 'regular', 17, 'Misty Hides / Land of Water Port', 120, 44, 44, 'agressivo', 127, 'Black Boars are a level 17 monster which lives in an area close to the Mist Village called Misty Hides and the Land of Water Port, similar to normal boars, only difference being their black fur.', '{}'),
  ('Dark Monkey King', 'boss', 57, 'Valley of the End (Leaf war zone)', 1, 781, 781, 'agressivo', 30000, 'The Dark Monkey King is a passive boss type monster found in the Valley of the End south of the Leaf Village. It''s a blackened version of the Monkey King summon.', '{"Whirlwind Kick","Breaking Kick"}'),
  ('Admiral Mitsuhide', 'boss', 60, 'Iron Tower', 72000, 768, 768, 'agressivo', 0, 'Admiral Mitsuhide is a level 60 boss. Considered as most difficult boss in game. He is located in the Iron Tower area, tower located in the most northern part of the Land Of Iron.', '{"Flicker","Metal Chain Technique","Dance of the Ronin","Crescent Moon Beheading"}'),
  ('Bear Hermit', 'boss', 30, 'Bear Hermit Cave', 16000, null, null, 'agressivo', 16000, null, '{}'),
  ('Bat', 'boss', 29, 'Hyoketsu Cave Entrance, Hyoketsu Prison', 290, null, null, 'agressivo', 180, null, '{}'),
  ('Crystal Slug', 'regular', 45, 'Crystal Beach Cave', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Daimaru', 'boss', 25, 'Level 20 Arc', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Captain Midora', 'boss', 58, 'Land of Iron', 38069, 40, 40, 'agressivo', 21750, null, '{}'),
  ('Blight Leech', 'regular', 20, 'Crystal Beach Cave', 175, 11, 11, 'agressivo', 150, null, '{}'),
  ('Crimson Leech', 'regular', 21, 'Crystal Beach Cave', 180, 12, 12, 'agressivo', 157, null, '{}'),
  ('Angry Hawk', 'enfurecido', 39, 'Level 30 story arc (see Story Lines)', 1625, 19, 19, 'agressivo', 0, null, '{}'),
  ('Bad Raccoon Bandit', 'regular', 1, 'Level 30 story arc (see Story Lines)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Big Scorpion', 'regular', 10, 'Desert Palms, Howling Canyon', 165, 18, 18, 'agressivo', 370, 'In combat it attacks at a range of 5 and respawns every 300 seconds. It has no special jutsu.', '{}'),
  ('Black Bear', 'regular', 1, 'Forest Near the Ledge', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Crab', 'regular', 21, 'Coral Walk, Ship', 150, 8, 8, 'passivo', 0, null, '{}'),
  ('Crazy Spider', 'regular', 10, 'Mountain Peak, Moist Plains, Lake Bell, Near the Valley', 160, 18, 18, 'agressivo', 370, 'In combat it attacks at a range of 5 and respawns every 300 seconds. It has no special jutsu.', '{}'),
  ('Chochin', 'regular', 62, 'Land of Spirits', 1400, 18, 18, 'agressivo', 465, 'The Chochin is a hostile yokai found in the Land of Spirits, twisted by the dark influence spreading through the spirit realm.', '{}'),
  ('Bakezori', 'regular', 61, 'Land of Spirits', 1350, 18, 18, 'agressivo', 457, 'The Bakezori is a hostile yokai found in the Land of Spirits, twisted by the dark influence spreading through the spirit realm.', '{}'),
  ('Armed Tengu Guard', 'regular', 69, 'Land of Spirits', 1800, 21, 21, 'agressivo', 517, 'The Armed Tengu Guard is a hostile Level 69 tengu yokai found in the Land of Spirits, a stronger variant of the Tengu Guard.', '{}'),
  ('Black Oni', 'regular', 69, 'Land of Spirits', 1700, 20, 20, 'agressivo', 517, 'The Black Oni is a hostile Level 69 oni yokai found in the Land of Spirits. It roams alongside the Blue Oni and the far stronger Red Oni.', '{}'),
  ('Blue Oni', 'regular', 68, 'Land of Spirits', 1600, 20, 20, 'agressivo', 510, 'The Blue Oni is a hostile Level 68 oni yokai found in the Land of Spirits. It roams alongside the Black Oni and the far stronger Red Oni.', '{}'),
  ('Brown Betobeto', 'regular', 1, 'Spiritevil Falls, Land of Spirits', 1, null, null, 'agressivo', 0, 'The Brown Betobeto is a hostile yokai found at Spiritevil Falls in the Land of Spirits.', '{}'),
  ('Angry Moth', 'boss', 1, 'Not yet confirmed', 1, null, null, 'agressivo', 0, 'The Angry Moth is a large mini boss version of the Moths.', '{}'),
  ('Big Snake', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Big Snake is an entry in the in-game Bestiary.', '{}'),
  ('Blue Crab', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Blue Crab is an entry in the in-game Bestiary.', '{}'),
  ('Desert Coyote', 'regular', 9, 'West Desert Valley', 60, 18, 18, 'passivo', 67, 'Desert Coyotes are a Level 9 MOBs which currently inhabit various locations around the Sand Village, most notably on the north of the village.', '{}'),
  ('Guren', 'boss', 1, null, 1, null, null, 'agressivo', 0, 'Guren is one of the Daimyo''s bodyguards, along with Gafuki and resides in Takumi Village with him.', '{}'),
  ('Gafuki', 'boss', 40, 'Takumi Village', 8900, 61, 61, 'agressivo', 16000, 'Gafuki is one of Daimyo''s guard dogs along with Guren.', '{"Wild Slashes","Body Flicker","Mud River","Shockwave slash","Substitution Technique"}'),
  ('Glacier Bear', 'regular', 37, 'Cold Cave, Chilling Inner Cave', 2000, 149, 149, 'agressivo', 0, 'Glacier Bears are a Level 37 Mob which currently inhabit Cold cave west of the Ledge.', '{"Body Flicker Technique"}'),
  ('Hawk', 'regular', 34, 'Toad Mountain Passage', 330, 78, 78, 'passivo', 254, 'Hawks are level 34 mobs. They take places around Toad Village.', '{"Body Flicker"}'),
  ('Hornet', 'regular', 28, 'Maps near Takumi Village and Tanzaku Quarters.', 155, 48, 48, 'agressivo', 226, 'Hornets are Level 28 monsters which currently inhabit areas near the Takumi Village and Tanzaku Quarters.', '{}'),
  ('Hebimaru', 'boss', 50, 'Hebimaru''s Lair', 3000, null, null, 'agressivo', 0, 'Hebimaru is BOSS-type enemy created by mad scientist Houo....Orochimaru.', '{"Bite","Hebimaru Venom","Poison Breath","Summon Hebimaru Spawns."}'),
  ('Dragonfly', 'regular', 5, 'Big Slope / By The River / Land of Water Bounty Station', 30, 8, 8, 'passivo', 37, 'Dragonflies are a level 5 Monsters who currently inhabit territories around the Mist Village like Big Slope, By The River and Land of Water Bounty Station.', '{}'),
  ('Fire Ant', 'regular', 7, 'Big Slope, 3 Way Road Split, Bloody Pond', 45, 16, 16, 'passivo', 50, 'Fire Ants are level 7 monsters inhabiting various areas around the Mist Village, such as Big Slope, 3 Way Road Split and Bloody Pond.', '{}'),
  ('Fox', 'regular', 9, 'By The River', 65, 6, 6, 'passivo', 67, 'Foxes are a level 9 monster found in various areas around the Mist Village, mainly By The River.', '{}'),
  ('Evil Spirit', 'regular', 23, 'Sealed Temple', 150, 39, 39, 'agressivo', 172, 'The Evil Spirit in a level 23 monster located in the Sealed Temple which can be accessed after unsealing a barrier tag in the ant cave.', '{}'),
  ('Dark Weasel', 'boss', 53, 'Sand War Zone', 1, 461, 461, 'agressivo', 22000, 'The Dark Weasel is a level 53 boss monster located in the Sand War Zone map east of the Sand Village.', '{"Dark Slicing Wind - 110 damage per hit<br>","Dark Wind Scythe - 110 damage per hit<br>","Flicker"}'),
  ('Emperor Penguin', 'regular', 51, 'Iron Cave, *Iron  Forest', 800, 178, 178, 'agressivo', 390, null, '{}'),
  ('Horned Samurai', 'regular', 57, 'Iron City', 2100, 187, 187, 'agressivo', 504, null, '{"Samurai Slash"}'),
  ('Gamakura', 'boss', 62, 'Toad Mountain Lake', 72000, 300, 300, 'agressivo', 0, null, '{}'),
  ('Enraged Wild Rabbit', 'enfurecido', 1, null, 1, null, null, 'agressivo', 0, null, '{}'),
  ('Duck', 'regular', 1, 'Asoki Port, Kenko Village, Coral Walk', 10, 0, 0, 'passivo', 0, null, '{}'),
  ('Enraged Tiger', 'enfurecido', 18, 'Striped Lake, The Forest Exit', 465, 18, 18, 'agressivo', 970, 'In combat it attacks at a range of 5 and respawns every 300 seconds. It has no special jutsu.', '{}'),
  ('Enraged Wolf', 'enfurecido', 13, 'Mountain Peak, Outskirts Deadend', 330, 18, 18, 'agressivo', 670, 'In combat it attacks at a range of 10 and respawns every 300 seconds. It has no special jutsu.', '{}'),
  ('Evil Black Boar', 'regular', 1, 'Land of Water Port, Riverbend Vale', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Fat Tunneler', 'regular', 1, 'Forgotten Sands, Beach Cave', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Fierce Dragonfly', 'regular', 1, 'Windy Pond, Big Slope, Land of Water Bounty Station, Oak Trail', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Gangster Daimaru', 'boss', 28, 'Land Of Waves (Level 20 arc)', 1320, 8, 8, 'agressivo', 1458, 'In combat it attacks at a range of 10 and respawns every 300 seconds. It uses 4 jutsu in combat.', '{}'),
  ('Gangster Han', 'boss', 30, 'Land Of Waves (Level 20 arc)', 2100, 8, 8, 'agressivo', 1511, 'In combat it attacks at a range of 7 and respawns every 300 seconds. It uses 4 jutsu in combat.', '{}'),
  ('Gangster Senkoji', 'boss', 26, 'Land Of Waves (Level 20 arc)', 1100, 7, 7, 'agressivo', 1032, 'In combat it attacks at a range of 20 and respawns every 300 seconds. It uses 4 jutsu in combat.', '{}'),
  ('Hasuka', 'boss', 1, 'Level 40 story arc (see Story Lines)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Huge Scarab', 'regular', 1, 'Desert Cave Entrance, Secret Desert Cavern', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Huge White Tiger', 'regular', 1, 'Sea Breeze Vale, Path to the River Country', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Green Oni', 'regular', 1, 'Spiritstone Hollow, Land of Spirits', 1, null, null, 'agressivo', 0, 'The Green Oni is a horned oni yokai sealed inside Spiritstone Hollow.', '{}'),
  ('Guard Hayate', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Guard Hayate is one of the two guards who patrol Hyoketsu Prison, alongside Guard Yetsuo. He is killable.', '{}'),
  ('Guard Yetsuo', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Guard Yetsuo is one of the two guards who patrol Hyoketsu Prison, alongside Guard Hayate. He is killable.', '{}'),
  ('Earth Puppet', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Earth Puppet is an entry in the in-game Bestiary.', '{}'),
  ('Eddie', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Eddie is an entry in the in-game Bestiary.', '{}'),
  ('Fire Puppet', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Fire Puppet is an entry in the in-game Bestiary.', '{}'),
  ('Guardian Spirit', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Guardian Spirit is an entry in the in-game Bestiary.', '{}'),
  ('Larva', 'regular', 1, 'Leaf Village Southern Outskirts, Larva Road, Sand Nesting Ground, Slight Slope.', 18, 3, 3, 'passivo', 12, 'Larvae are a Level 1 Mob which currently inhabit the multiple areas, most notably Sand Nesting Ground west of the sand village entrance, and Larva Road south-west of the Leaf Village Gates.', '{}'),
  ('Mutant Rat', 'regular', 23, 'Leaf Village Sewers', 155, 39, 39, 'agressivo', 172, 'Mutant Rats are Level 23 monsters which currently inhabit areas of Leaf Village Sewers under the Leaf Village.', '{}'),
  ('Raccoon Bandit', 'regular', 37, 'Toad Mountain Passage', 460, 85, 85, 'passivo', 254, 'Raccoon bandits are level 37 mobs. They take places around Toad Village.', '{"Wind Barrage","Body Flicker","Leaf Genjutsu"}'),
  ('Koji', 'boss', 40, 'Chilling Corridor', 7000, 140, 140, 'agressivo', 700, 'Koji is an Aggressive Mob found at the Chilling Corridor Map west of the Chilly Canyon.', '{"Bear Traps","Body Flicker","Sensory Technique","Exploding Spiked Ball","Substitution Technique"}'),
  ('Nelinel', 'boss', 44, 'Bandit Chief''s Yard', 1, 84, 84, 'agressivo', 0, 'Nelinel is a Level 44 boss who currently inhabits the single area Bandit Chief''s Yard.', '{"Water Bullet","Colliding Wave","Stun Smash","Body Flicker"}'),
  ('Kiemon', 'boss', 43, 'Icy Pathway', 6600, 55, 55, 'agressivo', 1750, 'Kiemon is a Level 43 boss who currently inhabits the single area Southern Bandit Encampment.', '{"Great Fireball","Phoenix Fireball","Body Flicker","Combusting Vortex","Substitution Technique"}'),
  ('Kumorui', 'boss', 30, 'Cave at the bottom of Dark Clearing', 4500, 66, 66, 'agressivo', 0, 'Kumorui is BOSS-type enemy hidden inside forest like cave, you can enter in the arena only at levels 20-30.', '{"Flicker","Web Shot"}'),
  ('Old Blood Puppet', 'regular', 53, 'Blood Puppet Factory', 1500, 356, 356, 'agressivo', 0, 'An even more ancient and powerful monster than the Blood Puppet. At level 53 it''s currently the highest level enemy.', '{"Metal Chain Technique - Flicker"}'),
  ('Koitaru', 'boss', 50, 'Cursed Laboratory (Sealed Box)', 1, 325, 325, 'passivo', 0, 'Koitaru is a level 50 boss located in a sealed box at the Cursed Laboratory entrance.', '{"Bone Spikes Technique 1 (All directions)","Bone Spikes Technique 2 (Wave)"}'),
  ('Leyasu / Ieyasu', 'boss', 50, 'Final Boss Room', 14500, 210, 210, 'agressivo', 6250, 'Leyasu, also written Ieyasu, is a level 50 boss and the leader of the bandits of the Level 40 arc.', '{"Flicker","Rare ground slam","Seismic Dash","Breaking Kick"}'),
  ('Kuraken', 'regular', 60, 'South-Eastern Sea III', 150000, 762, 762, 'agressivo', 0, 'The Kuraken is a sea monster of legend which is said to inhabit the South-Eastern Sea III map.', '{"Body Flicker","Bone Spikes"}'),
  ('Nobu', 'boss', 59, 'Iron Tower', 41000, 589, 589, 'agressivo', 0, 'General Nobu is a level 59 boss located in the Iron Tower area, in the most northern part of the Land Of Iron.', '{"Flicker","Dark Whirling Technique","Crescent Moon Behading"}'),
  ('Leno', 'boss', 32, 'Fallen Stones Gorge', 3500, 73, 73, 'agressivo', 2200, null, '{}'),
  ('King Bear', 'regular', 1, 'Forest Near the Ledge', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Lenno', 'boss', 1, 'Fallen Stone Gorge (ID 120)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Mad Desert Coyote', 'enfurecido', 1, 'Desert Oasis, West Desert Valley, Howling Canyon II', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Mother Scarab', 'regular', 1, 'Desert Cave Entrance (ID 39)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Overgrown Stinger', 'regular', 1, 'Sand Hive Grounds, Howling Canyon', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Prison Guards', 'regular', 1, 'Hyoketsu Prison (ID 19)', 1, null, null, 'passivo', 0, null, '{}'),
  ('Rabid Wolf', 'regular', 1, 'River Outskirts (ID 123)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Raging Boar', 'regular', 1, 'Verdant Edge II, Misty Hides', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Kappa', 'regular', 65, 'Land of Spirits', 1500, 19, 19, 'agressivo', 480, 'The Kappa is a hostile yokai found in the Land of Spirits, twisted by the dark influence spreading through the spirit realm.', '{}'),
  ('Karakasa', 'regular', 1, 'Spiritwind Ascent, Land of Spirits', 1, null, null, 'agressivo', 0, 'The Karakasa is a hostile umbrella yokai found around Spiritwind Ascent in the Land of Spirits.', '{}'),
  ('Ongaku', 'boss', 71, 'Land of Spirits', 21510, 42, 42, 'agressivo', 8866, 'Ongaku is a Level 71 boss yokai. With 21,510 health, a 10 minute respawn, and a long 18 tile range, she is one of the toughest fights in the region.', '{}'),
  ('Kikkumaru', 'boss', 74, 'Land of Spirits', 24150, 48, 48, 'agressivo', 9250, 'Kikkumaru is a Level 74 boss yokai of the Land of Spirits with 24,150 health and a 10 minute respawn.', '{}'),
  ('Jirou', 'boss', 72, 'Land of Spirits', 26292, 44, 44, 'agressivo', 9000, 'Jirou is a Level 72 boss yokai of the Land of Spirits with 26,292 health and a 10 minute respawn.', '{}'),
  ('Purple Oni', 'regular', 1, 'Spiritstone Hollow, Land of Spirits', 1, null, null, 'agressivo', 0, 'The Purple Oni is a horned oni yokai sealed inside Spiritstone Hollow.', '{}'),
  ('Mother Crystal Slug', 'regular', 42, 'Not yet documented', 4200, 20, 20, 'agressivo', 2500, 'The Mother Crystal Slug is a level 42 mob and the larger counterpart to the Crystal Slug.', '{}'),
  ('Karoshi', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Karoshi is an entry in the in-game Bestiary.', '{}'),
  ('Mad Emperor Penguin', 'enfurecido', 1, null, 1, null, null, 'agressivo', 0, 'Mad Emperor Penguin is an entry in the in-game Bestiary.', '{}'),
  ('Mother Slug', 'boss', 1, null, 1, null, null, 'agressivo', 0, 'Mother Slug is an entry in the in-game Bestiary.', '{}'),
  ('Nina', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Nina is an entry in the in-game Bestiary.', '{}'),
  ('Ninken', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Ninken is an entry in the in-game Bestiary.', '{}'),
  ('Panda King', 'boss', 1, null, 1, null, null, 'agressivo', 0, 'Panda King is an entry in the in-game Bestiary.', '{}'),
  ('Poison Puppet', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Poison Puppet is an entry in the in-game Bestiary.', '{}'),
  ('Scorpion', 'regular', 5, 'Desert Plains', 30, 10, 10, 'passivo', 37, 'Scorpions are Level 5 Mob which currently inhabit a few maps around the Sand Village.', '{}'),
  ('Spiderling', 'regular', 5, 'Moist Plains, Near the Valley', 30, 10, 10, 'passivo', 37, 'Spiderlings are Level 5 monsters which currently inhabit various locations around the Leaf Village, most notably Moist Plains and Near the Valley.', '{}'),
  ('Snakes', 'regular', 30, 'Hidden Lair', 215, 90, 90, 'agressivo', 250, 'Snakes are Level 30 monsters which currently inhabit Hidden Lair Entrance map.', '{}'),
  ('Venomous Snake', 'regular', 32, 'Hidden Lair', 230, 64, 64, 'agressivo', 255, 'Venomous Snakes are Level 32 monsters that currently inhabit the Hidden Lair map.', '{}'),
  ('Stinger', 'regular', 7, 'Sand Hive Grounds', 45, 16, 16, 'passivo', 50, 'Stingers are Level 7 monsters which currently inhabit the various maps around the Sand Village, most noticeably Sand Hive Grounds.', '{}'),
  ('Tunneler', 'regular', 17, 'Desert Oasis', 116, 44, 44, 'agressivo', 127, 'Tunnelers are a Level 17 Mob which currently inhabit Desert Oasis (west of the Sand Village) and Infested Desert Road.', '{}'),
  ('Scarab', 'regular', 13, 'Desert Cave Entrance', 85, 26, 26, 'agressivo', 97, 'Scarab are Level 13 monsters which currently inhabit one location, named the Desert Cave Entrance.', '{}'),
  ('Tiger', 'regular', 13, 'Striped Lake, The Forest Exit, , Path to the River Country', 85, 26, 26, 'agressivo', 97, 'Tigers are a Level 13 monsters which currently inhabit various locations around the Leaf Village, most notably East of Katabami Bridge.', '{}'),
  ('Tause', 'boss', 40, 'Southern Bandit Encampment', 2100, 62, 62, 'agressivo', 900, 'Tause are Level 40 Mob which currently inhabit the single area. Southern Bandit Encampment with his partner Takeshi at North of Icy Pathway.', '{"Body Flicker","Wild Slashes"}'),
  ('Takeshi', 'boss', 41, 'Southern Bandit Encampment', 1700, 128, 128, 'agressivo', 0, 'Takeshi is Level 41 boss who currently inhabits the single area Southern Bandit Encampment with his partner Tause North of Icy Pathway.', '{"Body Flicker","Fuuma Shuriken"}'),
  ('Reain', 'boss', 45, 'Bandit''s House', 3040, 92, 92, 'agressivo', 2200, 'Reain is a Level 45 boss who currently inhabits the single area Lake Stasis. She is here with her partner Chei and 5 Alpha Wolf.', '{"Wind Barrage","Slashing Tornado","Triple Slashing Tornadoes","Body Flicker","Substitution Technique"}'),
  ('Rat Kage', 'boss', 33, 'Leaf Village Sewers (F2)', 1550, 352, 352, 'passivo', 2050, null, '{"Lightning Senbon Technique","Lightning Spear Technique","Lighting Current Technique"}'),
  ('Tanuki', 'boss', 29, 'Bamboo Forest', 350, 67, 67, 'passivo', 0, 'Tanuki is a level 29 mini-boss type monster located in the Mist Bamboo Forest north of the Misty Hides.', '{"Leaf Genjutsu (stun)"}'),
  ('Samurai', 'regular', 56, 'Iron City', 1200, 227, 227, 'agressivo', 446, null, '{"Shockwave Slash","Body Flicker"}'),
  ('Romaji', 'boss', 50, 'Hunter''s Marsh', 23000, 306, 306, 'agressivo', 12500, null, '{"Dark Whirlwind Kick","Hunter Warglaive Boomerang","Hunter Warglaive Attack","Body Flicker","Subsitution Jutsu"}'),
  ('Reian', 'boss', 1, 'Level 40 story arc (see Story Lines)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Shizu', 'boss', 19, 'Kinsen Quarters (ID 18)', 1000, 10, 10, 'agressivo', 1183, 'In combat it attacks at a range of 8 and respawns every 300 seconds. It uses 5 jutsu in combat.', '{}'),
  ('Silk Moth', 'regular', 45, 'River Outskirts (ID 123)', 660, 16, 16, 'agressivo', 337, 'In combat it attacks at a range of 15 and respawns every 80 seconds. It uses 1 jutsu in combat.', '{}'),
  ('Spicy Venomous Snake', 'regular', 1, 'Abandoned Lair Entrance (ID 62)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Spirit Fox', 'regular', 1, 'By the River, Oak Trail', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Tsuchigumo', 'regular', 64, 'Land of Spirits', 1400, 18, 18, 'agressivo', 472, 'The Tsuchigumo is a hostile yokai found in the Land of Spirits, twisted by the dark influence spreading through the spirit realm.', '{}'),
  ('Tengu Guard', 'regular', 68, 'Land of Spirits', 1800, 21, 21, 'agressivo', 510, 'The Tengu Guard is a hostile Level 68 tengu yokai found in the Land of Spirits.', '{}'),
  ('Red Oni', 'regular', 70, 'Land of Spirits', 8500, 35, 35, 'agressivo', 4375, 'The Red Oni is a hostile Level 70 oni yokai found in the Land of Spirits. With 8,500 health, heavy damage, and a 5 minute respawn, it is the elite of the oni family.', '{}'),
  ('Red Betobeto', 'regular', 1, 'Spiritevil Falls, Land of Spirits', 1, null, null, 'agressivo', 0, 'The Red Betobeto is a hostile yokai found at Spiritevil Falls in the Land of Spirits.', '{}'),
  ('White Betobeto', 'regular', 1, 'Spiritevil Falls, Land of Spirits', 1, null, null, 'agressivo', 0, 'The White Betobeto is a hostile yokai found at Spiritevil Falls in the Land of Spirits.', '{}'),
  ('Shinkai Crab', 'boss', 56, 'Beach Cave (War Zone)', 16000, 25, 25, 'agressivo', 5000, 'The Shinkai Crab is an open world boss added on July 25, 2026.', '{"Seis ataques (temas de água","gelo e terra)"}'),
  ('Reyha', 'boss', 45, 'Desert (exact map not yet confirmed)', 10000, 25, 25, 'agressivo', 5000, 'Reyha is an open world boss added on August 9, 2026. She is a former Sand ninja who abandoned her village and now lives alone in the desert.', '{"Fights with a boomerang. Roaming NPC type since 18 August 2026"}'),
  ('Royal Spirit', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Royal Spirit is an entry in the in-game Bestiary.', '{}'),
  ('Scythe Weasel', 'boss', 1, null, 1, null, null, 'agressivo', 0, 'Scythe Weasel is an entry in the in-game Bestiary.', '{}'),
  ('Torii', 'boss', 1, null, 1, null, null, 'agressivo', 0, 'Torii is an entry in the in-game Bestiary.', '{}'),
  ('Trash Bag', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Trash Bag is an entry in the in-game Bestiary.', '{}'),
  ('War Toad', 'boss', 1, null, 1, null, null, 'agressivo', 0, 'War Toad is an entry in the in-game Bestiary.', '{}'),
  ('Weird Frog', 'regular', 1, null, 1, null, null, 'agressivo', 0, 'Weird Frog is an entry in the in-game Bestiary.', '{}'),
  ('Spooky Crow', 'regular', 1, null, 1, null, null, 'agressivo', 0, null, '{}'),
  ('Spooky Bat', 'regular', 1, null, 1, null, null, 'agressivo', 0, null, '{}'),
  ('Wolf', 'regular', 9, 'Outskirts Dead End', 60, 18, 18, 'passivo', 67, 'Wolves are Level 9 monsters which currently inhabit areas near the leaf village, most notably Outskirts Dead End.', '{}'),
  ('White Tiger', 'regular', 17, 'Striped Lake, The Forest Exit, Path to the River Country', 120, 44, 44, 'agressivo', 127, 'White Tigers are a Level 17 Mob which currently inhabit various locations around the Leaf Village, most notably on the south of the village.', '{}'),
  ('Wild Rabbit', 'regular', 3, 'Oak Trail', 1, null, null, 'passivo', 0, null, '{}'),
  ('Yuno', 'boss', 1, 'Mysterious Well (inside Crystallflow Falls, ID 26)', 1, null, null, 'agressivo', 0, null, '{}'),
  ('Yellow Oni', 'regular', 1, 'Spiritstone Hollow, Land of Spirits', 1, null, null, 'agressivo', 0, 'The Yellow Oni is a horned oni yokai sealed inside Spiritstone Hollow.', '{}')
on conflict (lower(name)) do update set
  category = excluded.category,
  level = excluded.level,
  location_note = excluded.location_note,
  hp = excluded.hp,
  damage_min = excluded.damage_min,
  damage_max = excluded.damage_max,
  combat_type = excluded.combat_type,
  xp_reward = excluded.xp_reward,
  description = excluded.description,
  special_abilities = excluded.special_abilities;

-- ---------------------------------------------------------------
-- Drops (mobs <-> itens)
-- ---------------------------------------------------------------
insert into mob_drops (mob_id, item_id, drop_rate) values
  ((select id from mobs where lower(name) = lower('Big Scarabs')), (select id from items where lower(name) = lower('Big Scarab Shell')), null),
  ((select id from mobs where lower(name) = lower('Big Scarabs')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Big Scarabs')), (select id from items where lower(name) = lower('Seji no Hani')), null),
  ((select id from mobs where lower(name) = lower('Bear')), (select id from items where lower(name) = lower('Bear Paw')), 10.0),
  ((select id from mobs where lower(name) = lower('Bear')), (select id from items where lower(name) = lower('Blank Scroll')), 1.0),
  ((select id from mobs where lower(name) = lower('Alpha Wolf')), (select id from items where lower(name) = lower('Wolf Fur')), 20.0),
  ((select id from mobs where lower(name) = lower('Alpha Wolf')), (select id from items where lower(name) = lower('Blank Scroll')), 5.0),
  ((select id from mobs where lower(name) = lower('Alpha Wolf')), (select id from items where lower(name) = lower('Prowler Pants')), 1.0),
  ((select id from mobs where lower(name) = lower('Alpha Wolf')), (select id from items where lower(name) = lower('Tanned Leather')), 5.0),
  ((select id from mobs where lower(name) = lower('Cursed Host')), (select id from items where lower(name) = lower('DNA Sample')), null),
  ((select id from mobs where lower(name) = lower('Cursed Host')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Cursed Host')), (select id from items where lower(name) = lower('Religious Katana')), null),
  ((select id from mobs where lower(name) = lower('Cursed Host')), (select id from items where lower(name) = lower('Iron Scythe')), null),
  ((select id from mobs where lower(name) = lower('Bee')), (select id from items where lower(name) = lower('Honey Comb')), null),
  ((select id from mobs where lower(name) = lower('Bee')), (select id from items where lower(name) = lower('Insect Wing')), null),
  ((select id from mobs where lower(name) = lower('Bee')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Bee Hive')), (select id from items where lower(name) = lower('Honey comb')), null),
  ((select id from mobs where lower(name) = lower('Chei')), (select id from items where lower(name) = lower('Black Masked Top')), 1.0),
  ((select id from mobs where lower(name) = lower('Chei')), (select id from items where lower(name) = lower('Black Bandit Shoes')), 1.0),
  ((select id from mobs where lower(name) = lower('Chei')), (select id from items where lower(name) = lower('Black Bandit Pants')), 1.0),
  ((select id from mobs where lower(name) = lower('Chei')), (select id from items where lower(name) = lower('Tonfa')), 1.0),
  ((select id from mobs where lower(name) = lower('Chei')), (select id from items where lower(name) = lower('Blood Vial')), 50.0),
  ((select id from mobs where lower(name) = lower('Blood Puppet')), (select id from items where lower(name) = lower('Puppet head')), null),
  ((select id from mobs where lower(name) = lower('Blood Puppet')), (select id from items where lower(name) = lower('Puppet limb')), null),
  ((select id from mobs where lower(name) = lower('Blood Puppet')), (select id from items where lower(name) = lower('Puppet string')), null),
  ((select id from mobs where lower(name) = lower('Blood Puppet')), (select id from items where lower(name) = lower('Blood Engine')), null),
  ((select id from mobs where lower(name) = lower('Ant')), (select id from items where lower(name) = lower('Ant Feelers')), null),
  ((select id from mobs where lower(name) = lower('Ant')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Boar')), (select id from items where lower(name) = lower('Boar Tusk')), null),
  ((select id from mobs where lower(name) = lower('Boar')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Black Boar')), (select id from items where lower(name) = lower('Boar Tusk')), null),
  ((select id from mobs where lower(name) = lower('Black Boar')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Black Boar')), (select id from items where lower(name) = lower('Dark Fur')), null),
  ((select id from mobs where lower(name) = lower('Dark Monkey King')), (select id from items where lower(name) = lower('Adamantine Staff')), null),
  ((select id from mobs where lower(name) = lower('Dark Monkey King')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Admiral Mitsuhide')), (select id from items where lower(name) = lower('Yamazaru')), null),
  ((select id from mobs where lower(name) = lower('Admiral Mitsuhide')), (select id from items where lower(name) = lower('Jakuma')), null),
  ((select id from mobs where lower(name) = lower('Bear Hermit')), (select id from items where lower(name) = lower('Black Bear Hood')), null),
  ((select id from mobs where lower(name) = lower('Bear Hermit')), (select id from items where lower(name) = lower('Black Arm Bandages')), null),
  ((select id from mobs where lower(name) = lower('Bear Hermit')), (select id from items where lower(name) = lower('Reinforced Bo Staff')), null),
  ((select id from mobs where lower(name) = lower('Bear Hermit')), (select id from items where lower(name) = lower('Raging Hermit Pants')), null),
  ((select id from mobs where lower(name) = lower('Bat')), (select id from items where lower(name) = lower('Bat Wings')), null),
  ((select id from mobs where lower(name) = lower('Bat')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Bat')), (select id from items where lower(name) = lower('Vigilante Bandana Mask Recipe')), null),
  ((select id from mobs where lower(name) = lower('Bat')), (select id from items where lower(name) = lower('Hokuto Sphere II')), null),
  ((select id from mobs where lower(name) = lower('Crystal Slug')), (select id from items where lower(name) = lower('Crystal Pipe')), null),
  ((select id from mobs where lower(name) = lower('Daimaru')), (select id from items where lower(name) = lower('Wooden Tonfa')), null),
  ((select id from mobs where lower(name) = lower('Captain Midora')), (select id from items where lower(name) = lower('Sukarabe Omo')), null),
  ((select id from mobs where lower(name) = lower('Captain Midora')), (select id from items where lower(name) = lower('Winter Scarf')), null),
  ((select id from mobs where lower(name) = lower('Captain Midora')), (select id from items where lower(name) = lower('Crystal Fan')), null),
  ((select id from mobs where lower(name) = lower('Captain Midora')), (select id from items where lower(name) = lower('Hokuto Sphere IV')), null),
  ((select id from mobs where lower(name) = lower('Captain Midora')), (select id from items where lower(name) = lower('Iron Piece')), null),
  ((select id from mobs where lower(name) = lower('Captain Midora')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Blight Leech')), (select id from items where lower(name) = lower('Black Folded Pants')), null),
  ((select id from mobs where lower(name) = lower('Blight Leech')), (select id from items where lower(name) = lower('Hokuto Sphere I')), null),
  ((select id from mobs where lower(name) = lower('Blight Leech')), (select id from items where lower(name) = lower('Leech Fang')), null),
  ((select id from mobs where lower(name) = lower('Blight Leech')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Blight Leech')), (select id from items where lower(name) = lower('Leech Shell')), null),
  ((select id from mobs where lower(name) = lower('Blight Leech')), (select id from items where lower(name) = lower('Black Backpack')), null),
  ((select id from mobs where lower(name) = lower('Crimson Leech')), (select id from items where lower(name) = lower('Red Folded Pants')), null),
  ((select id from mobs where lower(name) = lower('Crimson Leech')), (select id from items where lower(name) = lower('Hokuto Sphere II')), null),
  ((select id from mobs where lower(name) = lower('Crimson Leech')), (select id from items where lower(name) = lower('Leech Fang')), null),
  ((select id from mobs where lower(name) = lower('Crimson Leech')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Crimson Leech')), (select id from items where lower(name) = lower('Leech Shell')), null),
  ((select id from mobs where lower(name) = lower('Crimson Leech')), (select id from items where lower(name) = lower('Red Backpack')), null),
  ((select id from mobs where lower(name) = lower('Angry Hawk')), (select id from items where lower(name) = lower('Hawk Talon')), null),
  ((select id from mobs where lower(name) = lower('Angry Hawk')), (select id from items where lower(name) = lower('Hawk Feather')), null),
  ((select id from mobs where lower(name) = lower('Angry Hawk')), (select id from items where lower(name) = lower('Egg')), null),
  ((select id from mobs where lower(name) = lower('Angry Hawk')), (select id from items where lower(name) = lower('Tengai Hat')), null),
  ((select id from mobs where lower(name) = lower('Bad Raccoon Bandit')), (select id from items where lower(name) = lower('Raccoon Tail')), null),
  ((select id from mobs where lower(name) = lower('Bad Raccoon Bandit')), (select id from items where lower(name) = lower('Tanned Leather')), null),
  ((select id from mobs where lower(name) = lower('Big Scorpion')), (select id from items where lower(name) = lower('Scorpion Tail')), null),
  ((select id from mobs where lower(name) = lower('Black Bear')), (select id from items where lower(name) = lower('Black Bear Paws')), null),
  ((select id from mobs where lower(name) = lower('Black Bear')), (select id from items where lower(name) = lower('Tanned Leather')), null),
  ((select id from mobs where lower(name) = lower('Black Bear')), (select id from items where lower(name) = lower('Dark Barbarian Cloak Recipe')), null),
  ((select id from mobs where lower(name) = lower('Crab')), (select id from items where lower(name) = lower('Red Fighter Pants')), null),
  ((select id from mobs where lower(name) = lower('Crab')), (select id from items where lower(name) = lower('Red Striped Bucket Hat')), null),
  ((select id from mobs where lower(name) = lower('Crazy Spider')), (select id from items where lower(name) = lower('Spider Eggs')), null),
  ((select id from mobs where lower(name) = lower('Crazy Spider')), (select id from items where lower(name) = lower('Silk')), null),
  ((select id from mobs where lower(name) = lower('Desert Coyote')), (select id from items where lower(name) = lower('Canine Fang')), null),
  ((select id from mobs where lower(name) = lower('Desert Coyote')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Desert Coyote')), (select id from items where lower(name) = lower('Blue Folded Pants')), null),
  ((select id from mobs where lower(name) = lower('Guren')), (select id from items where lower(name) = lower('Blank Scroll')), 1.0),
  ((select id from mobs where lower(name) = lower('Gafuki')), (select id from items where lower(name) = lower('Great Grandfather''s Muramasa')), 5.0),
  ((select id from mobs where lower(name) = lower('Gafuki')), (select id from items where lower(name) = lower('Black Giant Folding Fan')), 5.0),
  ((select id from mobs where lower(name) = lower('Gafuki')), (select id from items where lower(name) = lower('Blank Scroll')), 5.0),
  ((select id from mobs where lower(name) = lower('Glacier Bear')), (select id from items where lower(name) = lower('Gray Bear Paw')), null),
  ((select id from mobs where lower(name) = lower('Glacier Bear')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Hawk')), (select id from items where lower(name) = lower('Hawk Talon')), null),
  ((select id from mobs where lower(name) = lower('Hawk')), (select id from items where lower(name) = lower('Hawk Feather')), null),
  ((select id from mobs where lower(name) = lower('Hawk')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Hornet')), (select id from items where lower(name) = lower('Honey Comb')), null),
  ((select id from mobs where lower(name) = lower('Hornet')), (select id from items where lower(name) = lower('Insect Wings')), null),
  ((select id from mobs where lower(name) = lower('Hornet')), (select id from items where lower(name) = lower('Blank Scroll.')), null),
  ((select id from mobs where lower(name) = lower('Hebimaru')), (select id from items where lower(name) = lower('Shirokata')), null),
  ((select id from mobs where lower(name) = lower('Hebimaru')), (select id from items where lower(name) = lower('Snake Rope Belt')), null),
  ((select id from mobs where lower(name) = lower('Hebimaru')), (select id from items where lower(name) = lower('Snake Inner Kimono')), null),
  ((select id from mobs where lower(name) = lower('Dragonfly')), (select id from items where lower(name) = lower('Dragonfly wings')), null),
  ((select id from mobs where lower(name) = lower('Dragonfly')), (select id from items where lower(name) = lower('Blank scroll')), null),
  ((select id from mobs where lower(name) = lower('Fire Ant')), (select id from items where lower(name) = lower('Ant Feelers')), null),
  ((select id from mobs where lower(name) = lower('Fire Ant')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Fox')), (select id from items where lower(name) = lower('Fox Fur')), null),
  ((select id from mobs where lower(name) = lower('Fox')), (select id from items where lower(name) = lower('Blank Scrolls')), null),
  ((select id from mobs where lower(name) = lower('Fox')), (select id from items where lower(name) = lower('Leather')), null),
  ((select id from mobs where lower(name) = lower('Evil Spirit')), (select id from items where lower(name) = lower('Undead Charm')), null),
  ((select id from mobs where lower(name) = lower('Evil Spirit')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Evil Spirit')), (select id from items where lower(name) = lower('Seathorn Pipe')), null),
  ((select id from mobs where lower(name) = lower('Dark Weasel')), (select id from items where lower(name) = lower('Dark Scythes')), null),
  ((select id from mobs where lower(name) = lower('Dark Weasel')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Emperor Penguin')), (select id from items where lower(name) = lower('Penguin Beak')), null),
  ((select id from mobs where lower(name) = lower('Emperor Penguin')), (select id from items where lower(name) = lower('Crystal Fan')), null),
  ((select id from mobs where lower(name) = lower('Emperor Penguin')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Horned Samurai')), (select id from items where lower(name) = lower('Iron Piece')), null),
  ((select id from mobs where lower(name) = lower('Horned Samurai')), (select id from items where lower(name) = lower('Iron Prison Key')), null),
  ((select id from mobs where lower(name) = lower('Horned Samurai')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Gamakura')), (select id from items where lower(name) = lower('Mizukane?')), null),
  ((select id from mobs where lower(name) = lower('Duck')), (select id from items where lower(name) = lower('Eggs')), null),
  ((select id from mobs where lower(name) = lower('Duck')), (select id from items where lower(name) = lower('Green Striped Bucket Hat')), null),
  ((select id from mobs where lower(name) = lower('Enraged Tiger')), (select id from items where lower(name) = lower('Tanned Leather')), null),
  ((select id from mobs where lower(name) = lower('Enraged Tiger')), (select id from items where lower(name) = lower('Straw Hat')), null),
  ((select id from mobs where lower(name) = lower('Enraged Wolf')), (select id from items where lower(name) = lower('Tanned Leather')), null),
  ((select id from mobs where lower(name) = lower('Evil Black Boar')), (select id from items where lower(name) = lower('Leather')), null),
  ((select id from mobs where lower(name) = lower('Evil Black Boar')), (select id from items where lower(name) = lower('Hanging Sakkat')), null),
  ((select id from mobs where lower(name) = lower('Fat Tunneler')), (select id from items where lower(name) = lower('White Folded Pants')), null),
  ((select id from mobs where lower(name) = lower('Fierce Dragonfly')), (select id from items where lower(name) = lower('Dragonfly Wings')), null),
  ((select id from mobs where lower(name) = lower('Fierce Dragonfly')), (select id from items where lower(name) = lower('Whiter Fighter Pants')), null),
  ((select id from mobs where lower(name) = lower('Fierce Dragonfly')), (select id from items where lower(name) = lower('Red Twinfall Scarf Recipe')), null),
  ((select id from mobs where lower(name) = lower('Gangster Daimaru')), (select id from items where lower(name) = lower('Finger')), null),
  ((select id from mobs where lower(name) = lower('Gangster Daimaru')), (select id from items where lower(name) = lower('Tengu Mask')), null),
  ((select id from mobs where lower(name) = lower('Gangster Han')), (select id from items where lower(name) = lower('Finger')), null),
  ((select id from mobs where lower(name) = lower('Gangster Han')), (select id from items where lower(name) = lower('Old Tengu Mask')), null),
  ((select id from mobs where lower(name) = lower('Gangster Senkoji')), (select id from items where lower(name) = lower('Finger')), null),
  ((select id from mobs where lower(name) = lower('Gangster Senkoji')), (select id from items where lower(name) = lower('Beaded Necklace')), null),
  ((select id from mobs where lower(name) = lower('Huge Scarab')), (select id from items where lower(name) = lower('Big Scarab Shells')), null),
  ((select id from mobs where lower(name) = lower('Huge Scarab')), (select id from items where lower(name) = lower('Green Folded Pants')), null),
  ((select id from mobs where lower(name) = lower('Huge Scarab')), (select id from items where lower(name) = lower('Seji No Hani')), null),
  ((select id from mobs where lower(name) = lower('Huge Scarab')), (select id from items where lower(name) = lower('Large Scarab Pincers')), null),
  ((select id from mobs where lower(name) = lower('Huge White Tiger')), (select id from items where lower(name) = lower('Tanned Leather')), null),
  ((select id from mobs where lower(name) = lower('Huge White Tiger')), (select id from items where lower(name) = lower('White Straw Hat')), null),
  ((select id from mobs where lower(name) = lower('Huge White Tiger')), (select id from items where lower(name) = lower('White Fighter Pants')), null),
  ((select id from mobs where lower(name) = lower('Larva')), (select id from items where lower(name) = lower('Cocoon')), null),
  ((select id from mobs where lower(name) = lower('Larva')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Mutant Rat')), (select id from items where lower(name) = lower('Rat Tail')), null),
  ((select id from mobs where lower(name) = lower('Mutant Rat')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Mutant Rat')), (select id from items where lower(name) = lower('Twin Fangs')), null),
  ((select id from mobs where lower(name) = lower('Raccoon Bandit')), (select id from items where lower(name) = lower('Raccoon Tail')), null),
  ((select id from mobs where lower(name) = lower('Raccoon Bandit')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Raccoon Bandit')), (select id from items where lower(name) = lower('Tales of a Gutsy Ninja')), null),
  ((select id from mobs where lower(name) = lower('Koji')), (select id from items where lower(name) = lower('White Bandit Mask')), 1.0),
  ((select id from mobs where lower(name) = lower('Koji')), (select id from items where lower(name) = lower('Black Bandit Mask')), 1.0),
  ((select id from mobs where lower(name) = lower('Nelinel')), (select id from items where lower(name) = lower('Red Scarf')), null),
  ((select id from mobs where lower(name) = lower('Nelinel')), (select id from items where lower(name) = lower('Double Arm Bandages')), null),
  ((select id from mobs where lower(name) = lower('Kiemon')), (select id from items where lower(name) = lower('Sashed Baggy Pants')), 1.0),
  ((select id from mobs where lower(name) = lower('Kiemon')), (select id from items where lower(name) = lower('Blood Vial')), 50.0),
  ((select id from mobs where lower(name) = lower('Kumorui')), (select id from items where lower(name) = lower('Leg Bandage')), null),
  ((select id from mobs where lower(name) = lower('Kumorui')), (select id from items where lower(name) = lower('Arm Bandage')), null),
  ((select id from mobs where lower(name) = lower('Kumorui')), (select id from items where lower(name) = lower('Chest Bandages')), null),
  ((select id from mobs where lower(name) = lower('Old Blood Puppet')), (select id from items where lower(name) = lower('Blood Engine')), null),
  ((select id from mobs where lower(name) = lower('Old Blood Puppet')), (select id from items where lower(name) = lower('Puppet string')), null),
  ((select id from mobs where lower(name) = lower('Old Blood Puppet')), (select id from items where lower(name) = lower('Puppet head')), null),
  ((select id from mobs where lower(name) = lower('Old Blood Puppet')), (select id from items where lower(name) = lower('Puppet limb')), null),
  ((select id from mobs where lower(name) = lower('Koitaru')), (select id from items where lower(name) = lower('Snake Belt')), null),
  ((select id from mobs where lower(name) = lower('Koitaru')), (select id from items where lower(name) = lower('Kotsuzui Tanto')), null),
  ((select id from mobs where lower(name) = lower('Koitaru')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Koitaru')), (select id from items where lower(name) = lower('Snake Inner Kimono')), null),
  ((select id from mobs where lower(name) = lower('Leyasu / Ieyasu')), (select id from items where lower(name) = lower('Demon Claws')), 1.0),
  ((select id from mobs where lower(name) = lower('Leyasu / Ieyasu')), (select id from items where lower(name) = lower('Blood Vial')), 50.0),
  ((select id from mobs where lower(name) = lower('Kuraken')), (select id from items where lower(name) = lower('Asarihanma')), null),
  ((select id from mobs where lower(name) = lower('Nobu')), (select id from items where lower(name) = lower('Blood Iron Fan')), null),
  ((select id from mobs where lower(name) = lower('Nobu')), (select id from items where lower(name) = lower('Adamantine Sword')), null),
  ((select id from mobs where lower(name) = lower('Leno')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Leno')), (select id from items where lower(name) = lower('Hohuto Sphere II')), null),
  ((select id from mobs where lower(name) = lower('Leno')), (select id from items where lower(name) = lower('Raging Hermit Shirt')), null),
  ((select id from mobs where lower(name) = lower('Leno')), (select id from items where lower(name) = lower('Canine Fang')), null),
  ((select id from mobs where lower(name) = lower('King Bear')), (select id from items where lower(name) = lower('Brownbear Paws')), null),
  ((select id from mobs where lower(name) = lower('King Bear')), (select id from items where lower(name) = lower('Tanned Leather')), null),
  ((select id from mobs where lower(name) = lower('Mad Desert Coyote')), (select id from items where lower(name) = lower('Leather')), null),
  ((select id from mobs where lower(name) = lower('Mad Desert Coyote')), (select id from items where lower(name) = lower('Blue Folded Pants')), null),
  ((select id from mobs where lower(name) = lower('Mother Scarab')), (select id from items where lower(name) = lower('Scarab Shell')), null),
  ((select id from mobs where lower(name) = lower('Overgrown Stinger')), (select id from items where lower(name) = lower('Scorpion Tail')), null),
  ((select id from mobs where lower(name) = lower('Rabid Wolf')), (select id from items where lower(name) = lower('Rabid Hide')), null),
  ((select id from mobs where lower(name) = lower('Rabid Wolf')), (select id from items where lower(name) = lower('Teeth')), null),
  ((select id from mobs where lower(name) = lower('Raging Boar')), (select id from items where lower(name) = lower('Leather')), null),
  ((select id from mobs where lower(name) = lower('Mother Crystal Slug')), (select id from items where lower(name) = lower('Blue Masked Top')), null),
  ((select id from mobs where lower(name) = lower('Mother Crystal Slug')), (select id from items where lower(name) = lower('Blue Bandit Mask')), null),
  ((select id from mobs where lower(name) = lower('Scorpion')), (select id from items where lower(name) = lower('Scorpion Tail')), null),
  ((select id from mobs where lower(name) = lower('Scorpion')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Spiderling')), (select id from items where lower(name) = lower('Spider Eggs')), null),
  ((select id from mobs where lower(name) = lower('Spiderling')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Snakes')), (select id from items where lower(name) = lower('Snake Venom')), null),
  ((select id from mobs where lower(name) = lower('Snakes')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Venomous Snake')), (select id from items where lower(name) = lower('Snake Venom')), null),
  ((select id from mobs where lower(name) = lower('Venomous Snake')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Stinger')), (select id from items where lower(name) = lower('Scorpion Tail')), null),
  ((select id from mobs where lower(name) = lower('Stinger')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Tunneler')), (select id from items where lower(name) = lower('Tunneler Tongue')), null),
  ((select id from mobs where lower(name) = lower('Tunneler')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Scarab')), (select id from items where lower(name) = lower('Scarab Shell')), null),
  ((select id from mobs where lower(name) = lower('Scarab')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Tiger')), (select id from items where lower(name) = lower('Tiger Fur')), null),
  ((select id from mobs where lower(name) = lower('Tiger')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Tiger')), (select id from items where lower(name) = lower('Straw Hat')), null),
  ((select id from mobs where lower(name) = lower('Tiger')), (select id from items where lower(name) = lower('Leather')), null),
  ((select id from mobs where lower(name) = lower('Tause')), (select id from items where lower(name) = lower('Black Bandit Blade')), 1.0),
  ((select id from mobs where lower(name) = lower('Tause')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Tause')), (select id from items where lower(name) = lower('Gas Mask')), 5.0),
  ((select id from mobs where lower(name) = lower('Tause')), (select id from items where lower(name) = lower('Blood Vial')), 50.0),
  ((select id from mobs where lower(name) = lower('Takeshi')), (select id from items where lower(name) = lower('Blood Vial')), null),
  ((select id from mobs where lower(name) = lower('Takeshi')), (select id from items where lower(name) = lower('Raging Bandit Pants')), null),
  ((select id from mobs where lower(name) = lower('Reain')), (select id from items where lower(name) = lower('Oriental Fan')), 1.0),
  ((select id from mobs where lower(name) = lower('Reain')), (select id from items where lower(name) = lower('Gloves Knuckle')), 1.0),
  ((select id from mobs where lower(name) = lower('Reain')), (select id from items where lower(name) = lower('Nitoryu Recipe')), 5.0),
  ((select id from mobs where lower(name) = lower('Reain')), (select id from items where lower(name) = lower('Blood Vial')), 50.0),
  ((select id from mobs where lower(name) = lower('Rat Kage')), (select id from items where lower(name) = lower('Rat Tail')), null),
  ((select id from mobs where lower(name) = lower('Rat Kage')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Rat Kage')), (select id from items where lower(name) = lower('Twin Blades')), null),
  ((select id from mobs where lower(name) = lower('Tanuki')), (select id from items where lower(name) = lower('Bamboo Hat')), null),
  ((select id from mobs where lower(name) = lower('Tanuki')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Samurai')), (select id from items where lower(name) = lower('Iron Piece')), null),
  ((select id from mobs where lower(name) = lower('Samurai')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Romaji')), (select id from items where lower(name) = lower('Hunters Warglaive')), 5.0),
  ((select id from mobs where lower(name) = lower('Romaji')), (select id from items where lower(name) = lower('Romaji Bandit Pants')), 20.0),
  ((select id from mobs where lower(name) = lower('Romaji')), (select id from items where lower(name) = lower('Hokutso Sphere III')), 5.0),
  ((select id from mobs where lower(name) = lower('Romaji')), (select id from items where lower(name) = lower('Blank Scroll')), 50.0),
  ((select id from mobs where lower(name) = lower('Romaji')), (select id from items where lower(name) = lower('Random Tools Pack')), 5.0),
  ((select id from mobs where lower(name) = lower('Romaji')), (select id from items where lower(name) = lower('Dark Veiled Sakkat Recipe')), 1.0),
  ((select id from mobs where lower(name) = lower('Shizu')), (select id from items where lower(name) = lower('Mobster Ring')), null),
  ((select id from mobs where lower(name) = lower('Silk Moth')), (select id from items where lower(name) = lower('Silk')), null),
  ((select id from mobs where lower(name) = lower('Silk Moth')), (select id from items where lower(name) = lower('Moth Wings')), null),
  ((select id from mobs where lower(name) = lower('Spicy Venomous Snake')), (select id from items where lower(name) = lower('Venom')), null),
  ((select id from mobs where lower(name) = lower('Spicy Venomous Snake')), (select id from items where lower(name) = lower('Red Poncho')), null),
  ((select id from mobs where lower(name) = lower('Spirit Fox')), (select id from items where lower(name) = lower('Leather')), null),
  ((select id from mobs where lower(name) = lower('Spirit Fox')), (select id from items where lower(name) = lower('Orange Striped Bucket Hat')), null),
  ((select id from mobs where lower(name) = lower('Spirit Fox')), (select id from items where lower(name) = lower('Tan Barbarian Cloak Recipe')), null),
  ((select id from mobs where lower(name) = lower('Shinkai Crab')), (select id from items where lower(name) = lower('See the Drops table below')), null),
  ((select id from mobs where lower(name) = lower('Reyha')), (select id from items where lower(name) = lower('See the Drops table below')), null),
  ((select id from mobs where lower(name) = lower('Wolf')), (select id from items where lower(name) = lower('Canine Fang')), null),
  ((select id from mobs where lower(name) = lower('Wolf')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Wolf')), (select id from items where lower(name) = lower('Red Folded Pants')), null),
  ((select id from mobs where lower(name) = lower('Wolf')), (select id from items where lower(name) = lower('Leather')), null),
  ((select id from mobs where lower(name) = lower('White Tiger')), (select id from items where lower(name) = lower('Tiger Fur')), null),
  ((select id from mobs where lower(name) = lower('White Tiger')), (select id from items where lower(name) = lower('Blank Scroll')), null),
  ((select id from mobs where lower(name) = lower('Wild Rabbit')), (select id from items where lower(name) = lower('Carrot')), null),
  ((select id from mobs where lower(name) = lower('Wild Rabbit')), (select id from items where lower(name) = lower('Rabbit Paw')), null),
  ((select id from mobs where lower(name) = lower('Yuno')), (select id from items where lower(name) = lower('Kazaruu Recipe')), null)
on conflict (mob_id, item_id) do update set
  drop_rate = excluded.drop_rate;

-- ---------------------------------------------------------------
-- Seed: Proficiências (migração 012, a partir do ninonline.fandom.com/wiki/Proficiencies)
-- ---------------------------------------------------------------
-- Migração 012: cadastro das Proficiências (Proficiencies) do jogo,
-- a partir de https://ninonline.fandom.com/wiki/Proficiencies,
-- https://ninonline.fandom.com/wiki/Weaving e https://ninonline.fandom.com/wiki/Cooking.
--
-- "Proficiencies" na wiki não são as maestrias de combate (fogo, vento,
-- taijutsu etc., já cadastradas na migração 007/tabela `masteries`) — são
-- 10 skills de coleta e crafting, cada uma com nível 1-500 e um bônus de
-- sucesso de 1% a cada 10 níveis (50% no cap). 4 são de coleta (Mining,
-- Woodcutting, Fishing, Foraging) e 6 são de crafting (Forging, Weaving,
-- Carpentry, Cooking, Transmutation, Fuinjutsu).
--
-- Escopo desta migração, conforme pedido: as 10 proficiências + as
-- receitas documentadas na wiki. Só Tecelagem (Weaving) e Culinária
-- (Cooking) têm página própria com lista de receitas — as outras 8
-- (incluindo Forjaria/Forging, que a wiki lista no hub mas cujo link
-- hoje só redireciona pra um resumo genérico sem dados) ainda não têm
-- receitas publicadas, só a descrição geral do que fazem.
--
-- Tecelagem: 24 receitas (17 com nível de desbloqueio conhecido + 7 que
-- só vêm de drop de mob, sem nível publicado). A wiki não documenta os
-- materiais/ingredientes dessas receitas, só o item final — por isso
-- essas entram sem linhas em `proficiency_recipe_materials`.
--
-- Culinária: 21 receitas, essas sim com ingredientes completos (a
-- página foi inteiramente re-documentada em 16/08/2026). Inclui a taxa
-- de sucesso base só pra Rice Ball (90%, confirmada em skill 0) e Fried
-- Egg (~50%, aproximada); as outras 19 não têm taxa/tempo de craft
-- registrados ainda.
--
-- Itens novos (materiais e produtos de receita que não existiam no
-- catálogo) foram criados com type = 'consumivel', já que o enum
-- item_type atual (anel/arma/roupa/consumivel/item_mob) não tem uma
-- categoria própria pra "ingrediente de crafting" — ajuste o tipo
-- manualmente no Admin pra roupas/acessórios craftados por Tecelagem
-- (chapéus, botas, calças, cachecóis, máscaras, capas) se quiser mais
-- precisão. Igual nas migrações anteriores, o "on conflict do nothing"
-- garante que reexecutar essa migração nunca sobrescreve um item que
-- você já editou manualmente.

do $$ begin
  create type proficiency_category as enum ('coleta', 'crafting');
exception
  when duplicate_object then null;
end $$;

create table if not exists proficiencies (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  category proficiency_category not null,
  description text,
  level_cap integer not null default 500,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists proficiencies_category_idx on proficiencies (category);

-- Uma receita pertence a uma proficiência, e opcionalmente aponta pro
-- item que ela produz (`output_item_id`) — null quando o item final
-- ainda não tiver sido cadastrado por algum motivo.
create table if not exists proficiency_recipes (
  id uuid primary key default gen_random_uuid(),
  proficiency_id uuid not null references proficiencies(id) on delete cascade,
  name text not null,
  output_item_id uuid references items(id) on delete set null,
  level_required integer,
  success_rate_base numeric(5, 2),
  craft_time_seconds integer,
  requires_workbench boolean not null default false,
  effect_description text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (proficiency_id, name)
);

create index if not exists proficiency_recipes_proficiency_id_idx on proficiency_recipes (proficiency_id);
create index if not exists proficiency_recipes_output_item_id_idx on proficiency_recipes (output_item_id);

-- Ingredientes de cada receita (n:n receita <-> item), só preenchido
-- quando a wiki documenta os materiais (hoje, só Culinária).
create table if not exists proficiency_recipe_materials (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references proficiency_recipes(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  quantity integer not null default 1,
  created_at timestamptz not null default now(),
  unique (recipe_id, item_id)
);

create index if not exists proficiency_recipe_materials_recipe_id_idx on proficiency_recipe_materials (recipe_id);
create index if not exists proficiency_recipe_materials_item_id_idx on proficiency_recipe_materials (item_id);

-- Migração 013: cadastro dos Anéis (Rings) do jogo, a partir de
-- https://ninonline.fandom.com/wiki/Rings e das 11 páginas individuais de
-- anel que tinham números exatos por raridade não repetidos no hub
-- (famílias Qi Ring, Chakra Vein Band e Spirit Rend Band).
--
-- Anéis são um tipo de equipamento cosmeticamente invisível — só dão
-- bônus de atributo, sem mudar a aparência do personagem. Cada anel
-- nomeado pode dropar em mais de uma raridade, cada raridade com um
-- bônus de atributo diferente (às vezes até duas variantes "Uncommon"
-- diferentes com o mesmo nome) — por isso os bônus ficam num array
-- jsonb `ring_variants` em vez de uma coluna fixa, um item por raridade
-- documentada.
--
-- 41 anéis cadastrados: 5 da família Qi Ring, 3 Chakra Vein Band, 3
-- Spirit Rend Band, 5 Bedrock Band, 4 Agate Ring, 5 Stargazer Ring, 12
-- Zodiac (incluindo Ring of the Jade Dragon, que não tem página própria
-- mas tem os dados completos no quadro-resumo da página Rings) e 4
-- avulsos sem família (Deathmarch Band, Eclipsed Crystal Ring, Shark
-- Tooth Ring, Moontide Pearl Ring).
--
-- Fora do escopo: o Kuronami Ring, que a própria wiki arquiva fora da
-- Category:Rings por ser restrito a membros da organização Neo-Akatsuki
-- (drop ao morrer, não faz parte do sistema normal de drop de anéis).
--
-- Lacunas de dados (documentadas por anel em `ring_notes`): variantes
-- Rare não capturadas de Granite/Basalt/Slate Bedrock Band nem Common de
-- Azurite Bedrock Band; Common/Uncommon do Iron Spirit Rend Band; uma
-- quinta cor (Fortitude) da família Agate Ring; a variante +7 do
-- Sapphire Stargazer Ring; e as variantes "4%"/"6%" mais fortes dos 3
-- anéis de crit/steal (Shark Tooth, Eclipsed Crystal, Deathmarch), das
-- quais só a mais fraca documentada (2% ou 4%) está aqui.
--
-- A família Qi Ring tem uma inconsistência da própria wiki entre
-- editores: a página da Sapphire Qi Ring descreve uma tabela de família
-- diferente da tabela genérica usada nas páginas de Amber/Amethyst/
-- Ruby/Topaz. Mantida como está — ver a nota da Sapphire Qi Ring.

alter table items add column if not exists ring_family text;
alter table items add column if not exists ring_level_required integer;
alter table items add column if not exists ring_variants jsonb;
alter table items add column if not exists ring_notes text;

create index if not exists items_ring_family_idx on items (ring_family);

-- ---------------------------------------------------------------
-- Seed: os 41 anéis
-- ---------------------------------------------------------------
insert into items (name, type, description, ring_family, ring_level_required, ring_variants, ring_notes) values
  ('Amber Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Strength": 1, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 2, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 1, "Agility": 2}}, {"rarity": "Rare", "stats": {"Strength": 2, "Agility": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Amethyst Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Intellect": 1, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 2, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 1, "Agility": 2}}, {"rarity": "Rare", "stats": {"Intellect": 2, "Agility": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Ruby Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Strength": 1, "Intellect": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 2, "Intellect": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 1, "Intellect": 2}}, {"rarity": "Rare", "stats": {"Strength": 2, "Intellect": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Topaz Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Common", "stats": {"Intellect": 1, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 2, "Agility": 1}}, {"rarity": "Uncommon", "stats": {"Intellect": 1, "Agility": 2}}, {"rarity": "Rare", "stats": {"Intellect": 2, "Agility": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Sapphire Qi Ring', 'anel', 'Originally developed by wandering ascetics, these rings harmonize with the user''s inner qi. They encourage a smoother circulation of chakra through the tenketsu points, slightly improving jutsu consistency and reducing wasted energy.', 'Qi Ring', 19, '[{"rarity": "Rare", "stats": {"Strength": 2, "Intellect": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Rare está documentada nesta página; a tabela de família na própria página da Sapphire diverge da tabela genérica usada nas páginas de Amber/Amethyst/Ruby/Topaz (ali, Ruby aparece como Uncommon +1 Str/+2 Int e Topaz como Rare +2 Int/+2 Agi) — inconsistência da própria wiki entre editores, mantida como está, sem tentar reconciliar.'),
  ('Silver Chakra Vein Band', 'anel', 'An enhanced shinobi tool embedded with micro-channels designed to resonate with the body''s chakra network. The band boosts internal stability, improving chakra regulation during jutsu execution.', 'Chakra Vein Band', 7, '[{"rarity": "Common", "stats": {"Chakra": 1}}, {"rarity": "Uncommon", "stats": {"Chakra": 2}}, {"rarity": "Rare", "stats": {"Chakra": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Steel Chakra Vein Band', 'anel', 'An enhanced shinobi tool embedded with micro-channels designed to resonate with the body''s chakra network. The band boosts internal stability, improving chakra regulation during jutsu execution.', 'Chakra Vein Band', 10, '[{"rarity": "Common", "stats": {"Chakra": 2}}, {"rarity": "Uncommon", "stats": {"Chakra": 3}}, {"rarity": "Rare", "stats": {"Chakra": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Uncommon e Rare confirmados contra o card do jogo em 25/08/2026.'),
  ('Mithril Chakra Vein Band', 'anel', 'An enhanced shinobi tool embedded with micro-channels designed to resonate with the body''s chakra network. The band boosts internal stability, improving chakra regulation during jutsu execution.', 'Chakra Vein Band', 12, '[{"rarity": "Common", "stats": {"Fortitude": 2, "Chakra": 1}}, {"rarity": "Uncommon", "stats": {"Fortitude": 1, "Chakra": 2}}, {"rarity": "Rare", "stats": {"Fortitude": 2, "Chakra": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Rare confirmado contra o card do jogo em 14/08/2026.'),
  ('Copper Spirit Rend Band', 'anel', 'Crafted by monks who studied the boundary between body and soul, it slightly sharpens the wearer''s fortitude.', 'Spirit Rend Band', 6, '[{"rarity": "Common", "stats": {"Fortitude": 1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Nível mais baixo entre os anéis documentados na wiki. Captado do card do jogo em 11/08/2026.'),
  ('Iron Spirit Rend Band', 'anel', 'Crafted by monks who studied the boundary between body and soul, it slightly sharpens the wearer''s fortitude.', 'Spirit Rend Band', 9, '[{"rarity": "Rare", "stats": {"Fortitude": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Rare foi confirmada; Common/Uncommon ainda não documentadas na wiki.'),
  ('Gold Spirit Rend Band', 'anel', 'Crafted by monks who studied the boundary between body and soul, it slightly sharpens the wearer''s fortitude.', 'Spirit Rend Band', 11, '[{"rarity": "Common", "stats": {"Fortitude": 1, "Chakra": 2}}, {"rarity": "Uncommon", "stats": {"Fortitude": 2, "Chakra": 1}}, {"rarity": "Rare", "stats": {"Fortitude": 2, "Chakra": 2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Granite Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Strength": 4, "Fortitude": 1}}, {"rarity": "Uncommon", "stats": {"Strength": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Sem variante Rare documentada na wiki.'),
  ('Basalt Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Fortitude": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Common está documentada.'),
  ('Slate Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Fortitude": 1, "Intellect": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Só a variante Common está documentada.'),
  ('Limestone Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Common", "stats": {"Fortitude": 1, "Agility": 4}}, {"rarity": "Uncommon", "stats": {"Fortitude": 1, "Agility": 5}}, {"rarity": "Rare", "stats": {"Agility": 6}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Azurite Bedrock Band', 'anel', null, 'Bedrock Band', 42, '[{"rarity": "Uncommon", "stats": {"Fortitude": 1, "Chakra": 5}}, {"rarity": "Rare", "stats": {"Chakra": 6}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Sem variante Common documentada.'),
  ('Red Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Common", "stats": {"Strength": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Purple Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Common", "stats": {"Intellect": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Blue Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Common", "stats": {"Chakra": 3}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Green Agate Ring', 'anel', null, 'Agate Ring', 30, '[{"rarity": "Uncommon", "stats": {"Agility": 4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Nenhuma cor de Fortitude foi documentada — se a família seguir o padrão de 5 cores (como Bedrock e Stargazer), falta uma.'),
  ('Ruby Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Strength": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Amethyst Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Fortitude": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Garnet Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Intellect": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Topaz Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Agility": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo.'),
  ('Sapphire Stargazer Ring', 'anel', null, 'Stargazer Ring', 55, '[{"rarity": "Common", "stats": {"Chakra": 5}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Existe uma variante +7 citada nas notas de patch (retaggeada de Rare pra Unique na v5.13.5), ainda não capturada em detalhe.'),
  ('Ring of the Sacred Ox', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Strength": 6}, "costs": {"Agility": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Boi. Um dos 12 Anéis do Zodíaco, adicionados em 17/02/2026 pro evento de Ano Novo Lunar, obtidos via Sealed Zodiac Ring dropado de mobs enfurecidos.'),
  ('Ring of the Brave Tiger', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Strength": 6}, "costs": {"Agility": -4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Tigre.'),
  ('Ring of the Wild Horse', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Fortitude": 6}, "costs": {"Strength": -1, "Intellect": -1, "Agility": -1, "Chakra": -1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Cavalo.'),
  ('Ring of the Wild Boar', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Fortitude": 6}, "costs": {"Strength": -1, "Intellect": -1, "Agility": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Javali.'),
  ('Ring of the Trickster Monkey', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Agility": 6}, "costs": {"Intellect": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Macaco.'),
  ('Ring of the Charging Ram', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Chakra": 6}, "costs": {"Strength": -1, "Intellect": -2, "Agility": -1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Carneiro.'),
  ('Ring of the Celestial Rat', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Chakra": 6}, "costs": {"Fortitude": -4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Rato.'),
  ('Ring of the Moon Hare', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Agility": 7}, "costs": {"Strength": -1, "Fortitude": -2, "Chakra": -1}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Coelho.'),
  ('Ring of the Vigilant Bird', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Intellect": 7}, "costs": {"Fortitude": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Galo.'),
  ('Ring of the Faithful Dog', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Intellect": 7}, "costs": {"Chakra": -4}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Cachorro.'),
  ('Ring of the Coiled Serpent', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Strength": 3, "Agility": 4}, "costs": {"Fortitude": -2, "Chakra": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Serpente.'),
  ('Ring of the Jade Dragon', 'anel', null, 'Zodiac', 15, '[{"rarity": null, "stats": {"Fortitude": 4, "Chakra": 3}, "costs": {"Strength": -1, "Intellect": -1, "Agility": -2}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Animal: Dragão. Sem página própria na wiki — dados só do quadro-resumo da página Rings.'),
  ('Deathmarch Band', 'anel', null, null, 65, '[{"rarity": "Unique", "stats": {"Fortitude": 2}, "percent": {"Life Steal": "2%"}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Retaggeado de Rare pra Unique na v5.13.5 (drop agora anunciado no chat global). A wiki documenta a variante 2%; uma variante 4% é citada mas não descrita em detalhe.'),
  ('Eclipsed Crystal Ring', 'anel', null, null, 65, '[{"rarity": "Unique", "stats": {"Chakra": 2}, "percent": {"Chakra Steal": "2%"}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Retaggeado de Rare pra Unique na v5.13.5 (drop agora anunciado no chat global). A wiki documenta a variante 2%; uma variante 4% é citada mas não descrita em detalhe.'),
  ('Shark Tooth Ring', 'anel', null, null, 49, '[{"rarity": "Unique", "stats": {"Strength": 1, "Agility": 1}, "percent": {"Critical Rate": "4%"}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Retaggeado de Rare pra Unique na v5.13.5. Uma variante 6% é citada mas não descrita em detalhe. Sem página própria — dados só do quadro-resumo da página Rings.'),
  ('Moontide Pearl Ring', 'anel', null, null, 50, '[{"rarity": "Legendary", "stats": {"Chakra": 8}}]'::jsonb, 'Anéis são cosmeticamente invisíveis — não mudam a aparência do personagem, só dão bônus de atributo. Único anel Legendary visto até agora. Dropa do mob Shinkai Crab (abaixo de 1%). Adicionado em 15/09/2026.')
on conflict (lower(name)) do update set
  ring_family = excluded.ring_family,
  ring_level_required = excluded.ring_level_required,
  ring_variants = excluded.ring_variants,
  ring_notes = excluded.ring_notes
where items.type = 'anel';

-- Migração 014: cadastro dos NPCs do jogo, extraídos de
-- https://ninonline.fandom.com/wiki/Category:NPC e Category:NPCs (68 páginas
-- ao todo, deduplicadas).
--
-- Escopo: todos os NPCs de diálogo/loja/missão da wiki (66 registros).
-- Ficaram de fora 6 páginas que são, na prática, entradas de Bestiário/
-- combate e não NPCs de diálogo:
--   - Guren: já cadastrado como mob (boss) na migração 011.
--   - Guard Hayate, Guard Yetsuo, Eddie, Karoshi, Nina: stubs de Bestiário
--     sem nenhum stat capturado (level/hp/local todos "Not recorded" na
--     wiki) — não fazem sentido nem em npcs nem em mobs ainda; quando
--     alguém capturar a ficha completa, cadastre como mob.
--
-- As duas páginas "hub" de loja de roupas (Mist Village Clothing Shop e
-- Sand Village Clothing Shop) foram desmembradas nos NPCs individuais que
-- de fato atendem o balcão (Tenma/Shimori/Gumi e Sako/Mako/Gumi
-- respectivamente), já que cada um tem estoque e papel próprios.
--
-- roles (npc_role[]): classificação heurística a partir do texto da
-- wiki (presença de seção "Missions", verbo "sells"/"shop", menção como
-- ponto de entrega de itens etc.) — revise/ajuste pelo Admin se algo saiu
-- errado. 'vendedor' = vende algo; 'concede_missao' = dá a missão
-- diretamente; 'parte_missao' = aparece na missão de outro NPC (alvo,
-- ponto de entrega, etc.) sem ser quem concede; 'outro' = só diálogo/lore,
-- sem papel mecânico capturado.
--
-- npc_shop_items (itens à venda) foi deixado de fora nesta migração:
-- a maior parte dos itens vendidos por esses NPCs é roupa (Clothes), que
-- ainda não foi cadastrada na tabela items (ver checklist). Os preços e
-- itens ficaram documentados em texto livre no campo description de
-- cada NPC; quando Clothes for cadastrado, popule npc_shop_items
-- separadamente.
--
-- arco_id / pin_id ficam null, mesmo padrão da migração 011 (mobs) —
-- posicionamento no mapa é manual, feito depois pelo admin.
--
-- missions.giver_npc_id: linkado só pros 5 casos em que o nome da
-- missão (migração 010) e o NPC concedente batem sem ambiguidade —
-- Warden Haoya (Your Best Behavior / Prison Work / Bat Clearance), Masumi
-- (Medicine Supplies II) e Himura (Medicine Supplies IV, cuja descrição
-- na migração 010 já cita "só aparece falando com Himura"). Os demais
-- "Mission giver" ficam só documentados em texto, sem link — a
-- correspondência entre o nome da missão no wiki e o nome cadastrado na
-- migração 010 nem sempre é exata o bastante pra linkar com segurança.


create unique index if not exists npcs_name_unique_idx on npcs (lower(name));

insert into npcs (name, roles, description, location_note) values
  ('Akio', ARRAY['outro']::npc_role[], 'Failed medical student who came to Takumi Village to take care of patients. A sociopath who enjoys developing dangerous medicines and antivenom that, ironically, help more than they harm.', 'Takumi Hospital, Takumi Village'),
  ('Daimyo', ARRAY['outro']::npc_role[], 'Frail old man, one of the richest NPCs in the game. Hires Missing Ninja to do his dirty work and protect his people. Protected by Guren and Gafuki. A second Daimyo (Kasai) rules the Land of Fire from the Tanzaku Quarters and outranks even the Hokage.', 'Takumi Village (also: Tanzaku Quarters, Land of Fire)'),
  ('Benkei', ARRAY['concede_missao']::npc_role[], 'Old master craftsman from the Land of Iron who fled after his romance with Princess Saeko was discovered. Now lives in Takumi Village. His mission (find his lost tools in the water) unlocks a special crafting function.', 'Takumi Village'),
  ('Gobori', ARRAY['concede_missao']::npc_role[], 'Middle-aged man born with "Snake Eyes" (can''t blink); former lumberjack, now a builder. His mission "Gobori''s Odd Request" asks for 23 Raccoon Tails, 23 Scorpion Tails and 23 Rat Tails (reward: 45 Ryo + 125k XP).', 'Takumi Village'),
  ('Fortune Teller', ARRAY['outro']::npc_role[], 'Sem informações detalhadas na wiki (página-stub, só categoria).', null),
  ('Duke', ARRAY['outro']::npc_role[], 'Ninja who specializes in taijutsu, claims it to be the best ninja art there is. Found resting beside a bench.', 'Far north of Leaf Village'),
  ('Chief Uzan', ARRAY['concede_missao']::npc_role[], 'Leader of the rebels opposed to the Samurai Faction and their oppression of the Land of Iron. Uncle of Yozune. Gives the mission "The Iron Tower".', 'Rebel Encampment, Land of Iron'),
  ('Daiken', ARRAY['concede_missao','vendedor']::npc_role[], 'Speaks primitively, like a caveman. Gives the mission "The Fur Maniac", which unlocks his Fur Shop (Brown Fur Cap 5000 Ryo, White Fur Cap 5000 Ryo, Fur Jacket 40000 Ryo).', 'Rebel Encampment, Land of Iron'),
  ('Guard Mika', ARRAY['concede_missao']::npc_role[], 'Guards the barricaded Rebel Encampment alongside Guard Tina. First NPC met at the mission desk, beginning the Land of Iron questline. Missions: "Talk to the Rebel Leader", "Guard the Barricades I".', 'Rebel Encampment, Land of Iron'),
  ('Guard Tina', ARRAY['concede_missao']::npc_role[], 'Guards the Rebel Encampment entrance alongside Guard Mika. Mission: "Guard the Barricade II".', 'Rebel Encampment, Land of Iron'),
  ('Ali Ali', ARRAY['concede_missao']::npc_role[], 'Keeps the materials for his Straw Cape secret; seems shady. Mission: "Cape of Straw".', 'Rebel Encampment, Land of Iron'),
  ('Hideyoshi', ARRAY['concede_missao']::npc_role[], 'Elderly man who longs for his grandson Saburo, who joined the Samurai in Iron City. Mission: "Ninja Evergarden".', 'Rebel Encampment, Land of Iron'),
  ('Bakan', ARRAY['concede_missao']::npc_role[], 'One-eyed lantern yokai standing outside a village building with a mission marker. Offers missions during the "Among the Yokai" questline.', 'Yokai Village, Land of Spirits'),
  ('Bunbuku', ARRAY['outro']::npc_role[], 'Tanuki wearing a woven hat, resting outside one of the Yokai Village buildings. Part of "Among the Yokai".', 'Yokai Village, Land of Spirits'),
  ('Goshinboku Tree', ARRAY['outro']::npc_role[], 'Sacred tree deep in the Land of Spirits, sealed off by ofuda on the Spiritcore Crater map. Once freed, reveals its binding seals were scattered deliberately; destroying every seal opens a hidden cave entrance. Focus of the mission "Binding Ofuda".', 'Spiritcore Crater, Land of Spirits'),
  ('Chef', ARRAY['vendedor']::npc_role[], 'Runs the Cooking Shop in Takumi Village; main source of Cooking recipes and core ingredients (e.g. Flour, 10 Ryo). Every recipe he sells requires Cooking Proficiency 18+. Does not sell Reaper Death Sauce (drops from Kiemon). Full stock list not transcribed.', 'Takumi Village'),
  ('Kimi', ARRAY['outro']::npc_role[], 'Ninja Tools Instructor. Her lesson consists of breaking supply boxes and correctly throwing five ninja tools at an adjacent target.', 'Leaf Village Academy'),
  ('Itori', ARRAY['parte_missao']::npc_role[], 'Former guard of the Leaf Village, retired after the addition of Leaf Jonin guards. Warns players of dangers outside the village. Part of the daily mission "Danger Dangos".', 'Leaf Village'),
  ('Himura', ARRAY['vendedor','parte_missao']::npc_role[], 'Runs the Leaf Medicine Shop. Sells pills that replenish health and chakra. Also the NPC players gather supplies for during the Medicine Supplies missions.', 'Leaf Medicine Shop, Leaf Village'),
  ('Innkeeper', ARRAY['concede_missao']::npc_role[], 'Runs the Inn in the Leaf Village. At level 12, offers a mission to find and unseal 4 seals hidden throughout the village.', 'Leaf Village Inn'),
  ('Inoki', ARRAY['outro']::npc_role[], 'Works part-time at the Leaf Flower Shop (players currently can''t buy flowers from her); spends the rest of her time as a ninja. Married.', 'Leaf Flower Shop, Leaf Village'),
  ('Kagane', ARRAY['vendedor']::npc_role[], 'One of Hidden Leaf''s Weapon-shop owners (Kagane''s Weapon Shop).', 'Far North-West of Leaf Village, near Stage 4: Leaf Village Arena'),
  ('Kaito', ARRAY['vendedor']::npc_role[], 'Born into a nomadic tribe that lived from cleaning battlefields. After saving enough money, left the tribe and opened a shop.', 'Takumi Village'),
  ('Tenma', ARRAY['vendedor']::npc_role[], 'One of the twin sellers inside the Mist Village Clothing Shop. Wares: Striped Shirts/Pants/Shoes 100 each, Netted Shirt 200, Baggy Pants 200 each, Pants 100 each, Black Shoes 50.', 'Mist Village Clothing Shop, Mist Village (Northwest)'),
  ('Shimori', ARRAY['vendedor']::npc_role[], 'One of the twin sellers inside the Mist Village Clothing Shop. Wares: Long Shirt 200, Jackets 200 each, Black Gloves 100, Shorts 100 each, Turtle Neck Shirt 500, Blue Short Jacket 500, Blue Short Pants 500, Blue Jackets 5000 each, Simple Silk Robe 300, Blue Scarf 500.', 'Mist Village Clothing Shop, Mist Village (Northwest)'),
  ('Gumi (Mist Village)', ARRAY['outro']::npc_role[], 'Cash Shop NPC inside the Mist Village Clothing Shop: offers a preview of Cash Shop items and a Stash for items already purchased.', 'Mist Village Clothing Shop, Mist Village (Northwest)'),
  ('Mirai', ARRAY['vendedor']::npc_role[], 'Fortune-teller who works at the Horoscopes & Charms building, determining a shinobi''s fate. 500 Ryo for a fate reading, 10 Ryo for a charm.', 'Horoscopes & Charms, Takumi Village'),
  ('Ko', ARRAY['concede_missao']::npc_role[], 'Swordsman residing inside the snake lair. Offers the mission "The Venomous Requirement" (retrieve 100 snake venom); completing it unlocks access to the second floor.', 'Snake lair'),
  ('Master Zen', ARRAY['concede_missao']::npc_role[], 'Teacher of Yin and Yang. Mission: "Haiku 57-5".', 'Rebel Encampment, Land of Iron'),
  ('Iroh', ARRAY['parte_missao']::npc_role[], 'Grandfather of Suki, retired General of the Land of Iron. Imprisoned by the Samurai in Iron City; appears at the Rebel Encampment next to his granddaughter after being freed.', 'Iron City / Rebel Encampment, Land of Iron'),
  ('Kampo', ARRAY['parte_missao']::npc_role[], '"The Beggar". Prompts the player to donate 1, 2, or 3 Ryo. Donating at least 10 Ryo total is required to gain access to Oson''s level 38+ quest "Revenge on Kuraken".', 'Mist Village, near the West entrance, down the closest waterfall'),
  ('Hosoku', ARRAY['vendedor']::npc_role[], 'Specialized clothing merchant. Wares (prices not documented, shown as "???"): Rich Cap, Yuki-Onna Mask, Ocean Mist Dress, Blood Mist Dress, Yagyu Traditional Shirt, Yagyu Traditional Pants.', 'Asoki Village'),
  ('Lady Kitsune', ARRAY['concede_missao']::npc_role[], 'The Fox Princess, guardian of the Land of Spirits. Watches over Yokai Village from her temple; gives the missions of the Land of Spirits storyline (start of "Among the Yokai"). Reveals the balance holding the Land of Spirits together is fracturing.', 'Yokai Village temple, Land of Spirits'),
  ('Hito', ARRAY['outro']::npc_role[], 'Small one-eyed humanoid yokai in blue, resident of the Yokai Village. Part of "Among the Yokai".', 'Yokai Village, Land of Spirits'),
  ('Masumi', ARRAY['concede_missao']::npc_role[], 'Sand Village Herbalist, runs a stall in the village. Mission giver for "Medicine Supplies II" (Rank B), asking for 25 Spider Eggs and 30 Snake Venom.', 'Sand Village'),
  ('Satoshi', ARRAY['outro']::npc_role[], 'Basic Combat Instructor. His lesson can only be learned once, without reset.', 'Leaf Village Academy'),
  ('Shizuna', ARRAY['outro']::npc_role[], 'Technique Instructor. Her lesson can only be learned once, without reset.', 'Leaf Village Academy'),
  ('Summoning Toad', ARRAY['vendedor']::npc_role[], 'For 100 Ryo, summons supply boxes around the Leaf or Sand Village (each box: 1 Kunai, 1 Shuriken, 1 Senbon). Also sells portals: Land of Toads (50 Ryo, after the Land of Toads collection chain) and Land of Iron (100 Ryo, after level 50 and speaking to Guard Mika).', 'Leaf Village and Sand Village, east of the hospital'),
  ('Sako', ARRAY['vendedor']::npc_role[], 'One of the twin sellers inside the Sand Village Clothing Shop. Wares: Bandaged Shirts 100, Sleeveless Shirts 100, Netted Shirt 200, Shoes 50, Pants 100, Sashed Jackets 200, Simple Silk Robe 300, Kimonos 2000.', 'Sand Village Clothing Shop, West of the Kazekage Office'),
  ('Mako', ARRAY['vendedor']::npc_role[], 'One of the twin sellers inside the Sand Village Clothing Shop. Wares: Scarfed Sand Robe 2500, Short Cloaks 500, Long Scarfs 500, Shorts 100, Turtleneck Shirt 300, Blue Scarf 500, Jackets 5000, Long Coats 35000, Pink Blue Skirt Combo 500.', 'Sand Village Clothing Shop, West of the Kazekage Office'),
  ('Gumi (Sand Village)', ARRAY['outro']::npc_role[], 'Cash Shop NPC inside the Sand Village Clothing Shop: offers a preview of Cash Shop items and a Stash for items already purchased.', 'Sand Village Clothing Shop, West of the Kazekage Office'),
  ('Mugen', ARRAY['vendedor']::npc_role[], 'Old man, the last inhabitant of the old Komori Village in the Land of Wind. Former puppeteer ninja. Tells the story of the old Komori Village and enchants wooden weapons. Crafts Blood Katana (1 Wooden Katana + puppet pieces + 1 Blood Engine) and Blood Tonfas (1 Tonfa + puppet pieces + 1 Blood Engine).', 'Old Komori Village, Land of Wind'),
  ('Sarugami', ARRAY['outro']::npc_role[], 'Rumored to be a legendary shinobi from the Great Ninja War, with a group of followers in the Cursed Laboratory who claim he gave them great powers with drawbacks. In the future is supposed to give missions.', 'Cursed Laboratory'),
  ('Sayaki', ARRAY['concede_missao']::npc_role[], 'Ninja of the Mist Village, sister of Himiki from Takumi Village (they look identical). Offers the mission "Twin Sister Delivery" (deliver her parcel to her sister).', 'Mist Village'),
  ('Oson', ARRAY['concede_missao']::npc_role[], 'Lives on an island in the South-Eastern Sea IV map, daughter of Iphan and member of the Angsan bloodline (creates "Null Zones"). Won''t talk unless the player donated to Kampo first. Gives "Revenge on Kuraken" (level 38+) to avenge her father, killed by the Kuraken. Can fully heal the player''s HP to help cross the sea.', 'South-Eastern Sea IV'),
  ('Pipe Seller', ARRAY['vendedor']::npc_role[], 'For 500 Ryo, sells a Bubble-Utilising Pipe — an exclusive sub-path element for Mist shinobi specializing in bubbles.', 'Mist Village Indoor Market'),
  ('Pakko', ARRAY['concede_missao']::npc_role[], 'Young girl who loves to play "Fill the Bucket". Mission: "Fill the Bucket".', 'Rebel Encampment, Land of Iron'),
  ('Suki', ARRAY['concede_missao']::npc_role[], 'Young girl waiting outside the barricade, awaiting the return of her grandfather Iroh, taken prisoner by the Samurai. Mission: "Rescue grandpa Iroh".', 'Rebel Encampment, Land of Iron'),
  ('Saburo', ARRAY['parte_missao']::npc_role[], 'Grandson of Hideyoshi. Joined the Samurai to prove himself, works in their armory in Iron City. Upon completion of "Ninja Evergarden", returns to the Rebel Encampment to protect his grandfather.', 'Iron City / Rebel Encampment, Land of Iron'),
  ('Okuri', ARRAY['concede_missao']::npc_role[], 'Researcher in the Land of Spirits studying how corruption affects the yokai. Sends ninja to gather field data. Missions: "Echos of Yokai I"–"V" (B Rank, storyline chain).', 'Land of Spirits'),
  ('Rokuro', ARRAY['concede_missao']::npc_role[], 'Directs ninja to hunt evil yokai still lingering after the Land of Spirits arc''s events. Missions: "Cleanse the Remnants I", "II" (A Rank), "Remnants of the Wicked I" (A Rank).', 'Land of Spirits'),
  ('Nekomata', ARRAY['concede_missao']::npc_role[], 'Grey two-tailed cat yokai, resident of the Yokai Village. Missions: "Cleanse the Forest I"–"V" (B Rank) and "Balanced Waters".', 'Yokai Village, Land of Spirits'),
  ('Ningyo', ARRAY['outro']::npc_role[], 'Mermaid-like yokai found near the water, resident of the Yokai Village. Part of "Among the Yokai".', 'Yokai Village, Land of Spirits'),
  ('Rizo', ARRAY['concede_missao']::npc_role[], 'Mission giver for the entire Bandit Questline (level 40 arc): all ten "Bandits I"–"X" missions, plus three repeatable missions (level 44+): "Bandit Hunt I"/"II" (B, 3x Blood Pill) and "The Wolf Pack" (C, 3x Chakra Pill).', 'Bandit Area (Level 40 arc)'),
  ('Yori', ARRAY['outro']::npc_role[], 'One of the first NPCs players meet in the Leaf Village. Main academy teacher; proctors the player''s way to Genin.', 'Leaf Village Academy'),
  ('Yasuo', ARRAY['vendedor']::npc_role[], 'Scroll-shop owner. Enchants Blank Scrolls into Sealable Scrolls (Tier I/II/III — higher tier, lower success chance). Also writes Sealable Scrolls into Technique Manuals matching their tier.', 'Hidden Leaf Village'),
  ('Tora', ARRAY['parte_missao']::npc_role[], 'Cat used in a D-Rank mission: find her in a nearby forest and return her to the owner.', 'Forest near Leaf Village'),
  ('Zabuto', ARRAY['vendedor']::npc_role[], 'Rogue ninja in the Cursed Laboratory, expert in poison crafting. Crafts the Poison-Laced Kunai Dagger for 500 Ryo + 100 Snake venom + 5 Prawn Sushi + 1 Kunai Dagger.', 'Cursed Laboratory'),
  ('Yozune', ARRAY['concede_missao']::npc_role[], 'Nephew of Chief Uzan, found with his pet panda. Mission: "Panda Food is Penguin Beaks!?".', 'Rebel Encampment, Land of Iron'),
  ('Tenkei', ARRAY['vendedor']::npc_role[], 'Operates a Ninja Tools Shop.', 'Rebel Encampment, Land of Iron'),
  ('Yin', ARRAY['concede_missao']::npc_role[], 'Rebel swordsman who trains under Master Zen alongside his rival Yang. Mission: "Stronger than the Samurai I".', 'Rebel Encampment, Land of Iron'),
  ('Yang', ARRAY['concede_missao']::npc_role[], 'Rebel fan user who trains under Master Zen alongside her rival Yin. Mission: "Stronger than the Samurai II".', 'Rebel Encampment, Land of Iron'),
  ('Yami', ARRAY['outro']::npc_role[], 'Black cat yokai found inside one of the Yokai Village shops. Part of "Among the Yokai".', 'Yokai Village, Land of Spirits'),
  ('Yuki', ARRAY['outro']::npc_role[], 'Pale woman in a blue kimono standing beneath a great tree, resident of the Yokai Village. Part of "Among the Yokai".', 'Yokai Village, Land of Spirits'),
  ('Yuu', ARRAY['concede_missao']::npc_role[], 'Civilian girl in Takumi Village, not a ninja. Starting NPC for "Hidden Tomb - (Takumi Seals)" (Main rank, level 25, 68,000 EXP) — puts the seven Takumi seals into the world and opens the Tomb of Royalty questline. Offers a secret about the village in exchange for releasing the chakra-infused seals.', 'Under the great tree outside the Takumi hospital, Takumi Village'),
  ('Warden Haoya', ARRAY['concede_missao']::npc_role[], 'Warden of Hyoketsu Prison, giver of all three prison missions (repeatable, reduce Crime score instead of paying Ryo): "Your Best Behavior" (lvl 1+, -2 crime, 33 exp), "Prison Work" (lvl 10+, -4 crime, 520 exp), "Bat Clearance" (lvl 20+, -4 crime, 5200 exp). Also the turn-in point for the ore/herb handover on Prison Work. Boss NPC: Level 50, 9000 HP.', 'Hyoketsu Prison Warden Office')
on conflict (lower(name)) do update set
  roles = excluded.roles,
  description = excluded.description,
  location_note = excluded.location_note;

-- Linka NPCs concedentes às missões diárias já cadastradas (migração 010).
update missions set giver_npc_id = (select id from npcs where lower(name) = lower('Warden Haoya'))
  where lower(name) = lower('Your Best Behavior');
update missions set giver_npc_id = (select id from npcs where lower(name) = lower('Warden Haoya'))
  where lower(name) = lower('Prison Work');
update missions set giver_npc_id = (select id from npcs where lower(name) = lower('Warden Haoya'))
  where lower(name) = lower('Bat Clearance');
update missions set giver_npc_id = (select id from npcs where lower(name) = lower('Masumi'))
  where lower(name) = lower('Medicine Supplies II');
update missions set giver_npc_id = (select id from npcs where lower(name) = lower('Himura'))
  where lower(name) = lower('Medicine Supplies IV');

-- Migração 015: cadastro das Clothes (roupas/cosméticos) do jogo, extraídas
-- de https://ninonline.fandom.com/wiki/Category:Clothing (335 páginas na
-- categoria).
--
-- Escopo: registro completo pedido pelo usuário -- raridade, slot de
-- equipamento e como obter, extraídos de cada página via script (parse do
-- infobox de cada item, não releitura manual página a página). 306 itens
-- cadastrados como `items.type = 'roupa'`.
--
-- Ficaram de fora 29 páginas:
--   - 4 são páginas-índice/meta, não itens em si: "Event-exclusive items",
--     "Role-gated equipment", "Mist Village Clothing Shop" e "Sand Village
--     Clothing Shop" (lojas já documentadas via NPCs na migração 014).
--   - 25 são páginas "hub" de família de cor (ex.: "Adventure Cloak", "War
--     Mantle", "Bandit Mask", "Visor") que só descrevem o conjunto -- cada
--     cor tem sua própria página com dados completos (ex.: "Black Adventure
--     Cloak", "Blue War Mantle") e é essa página individual que foi
--     cadastrada. Duas famílias com nomes parecidos (ex. "Ragged Poncho",
--     "Jira Vest", "Sakkat", "Bear Hood", "High Heel Boots", "Tenegui Towel
--     Hat", "Snake Rope Belt", "Top Hat", "Wanderer Shirt") NÃO são hubs --
--     são item real e comprável por si só (preço/loja próprios na própria
--     página) e foram mantidas.
--
-- Novas colunas em `items` (nulas pra qualquer item que não seja roupa):
--   - clothing_slot: slot de equipamento como a wiki descreve (Hat, Vest,
--     Shirt, Mask, Pants, Accessory, Cape, Outfit, Footwear...) -- texto
--     livre, não enum, porque a wiki não é consistente o bastante pra um
--     enum fechado.
--   - clothing_rarity: raridade/classe do item conforme o item card do
--     jogo (Common/Uncommon/Rare/Legendary/Unique/Premium/Event/Crafted/
--     Enchanted/Drop/Clan/Cash/Recipe Drop). Nula quando a wiki não
--     documentou.
--   - clothing_level_required: nível mínimo, quando documentado (null
--     quando a wiki diz "Any" ou não documenta).
--   - clothing_price_ryo: preço em Ryo como número, só quando o preço da
--     wiki é um valor simples "N Ryo" (a maioria das roupas Premium/Cash
--     Shop tem preço em dólar, War Tokens, Event Coupons ou Halloween
--     Token -- esses ficam só em clothing_price_text).
--   - clothing_price_text: preço como a wiki documenta, em texto livre
--     (cobre USD do Cash Shop, War Tokens, Event Coupons, Halloween Token,
--     "Not sold" pra recompensas de conquista etc).
--   - clothing_source: onde obter (loja e/ou NPC), texto livre.
--   - clothing_notes: nota de lacuna de dados -- hoje só marca os itens
--     cuja página não tinha o infobox padrão {{Item_Template}} /
--     {{Infobox/Items}} (extraídos do texto corrido da página).
--
-- Reclassificação automática de itens de drop de mob: várias roupas desta
-- lista (ex. Snake Rope Belt, Gas Mask, Beaded Necklace, Chest Bandages,
-- Tengai Hat, Wanderer Shirt, e outras ~40) já existiam na tabela `items`
-- como `type = 'item_mob'` -- criadas automaticamente pela migração 011
-- (mobs) como placeholder sem descrição, porque na época a categoria
-- Clothes ainda não tinha sido cadastrada. Esta migração reclassifica esse
-- placeholder pra `type = 'roupa'` e preenche os dados, mas só quando o
-- item ainda está sem descrição (nunca sobrescreve um item que o admin já
-- editou manualmente com type diferente de 'roupa'/'item_mob' vazio).
--
-- Raridade/slot têm ruído conhecido na wiki (texto de tabela vazando pro
-- campo errado em algumas infoboxes antigas) -- o parser descarta valores
-- fora da lista de raridades conhecidas, deixando null em vez de lixo.
-- Revise pelo Admin caso encontre algo estranho.

alter table items add column if not exists clothing_slot text;
alter table items add column if not exists clothing_rarity text;
alter table items add column if not exists clothing_level_required integer;
alter table items add column if not exists clothing_price_ryo integer;
alter table items add column if not exists clothing_price_text text;
alter table items add column if not exists clothing_source text;
alter table items add column if not exists clothing_notes text;
create index if not exists items_clothing_slot_idx on items (clothing_slot);

insert into items (name, type, description, clothing_slot, clothing_rarity, clothing_level_required, clothing_price_ryo, clothing_price_text, clothing_source, clothing_notes) values
  ('ANBU Vest', 'roupa', 'A Padded Vest that members of the Leaf ANBU wear, unlike a standard flak vest it sacrifices some protection for increased mobility. You are required to have a level of 30 or above to utilize this item. You can obtain them from the Leaf ANBU Equipment Shop for the price of 2,500 Ryo. Only members of the Leaf Village ANBU can wear this item.', 'Vest', 'Rare', 30, 2500, '2,500 Ryo', 'Leaf ANBU Equipment Shop', null),
  ('Black Shoes', 'roupa', 'This is a basic equipment that protects your baby feet from sharp objects like broken beer bottles, lego pieces, destroyed headbands, etc.', 'Shoe', null, null, 50, '50 Ryo', null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Arm Bandages', 'roupa', 'Tattered dressings which the user wraps around their arm. It makes you swift like a cobra. You are required to have a level of 5 or above to utilize this item. You can obtain it at the Takumi Village Clothing Shop or by defeating Kumorui, the spider king.', 'Accessory', 'Uncommon', 5, 250, '250 Ryo', 'Takumi Village Clothing Store — NPC: Kumorui', null),
  ('Black Long Sleeved Shirt', 'roupa', 'A long sleeved black shirt that also comes in other colors', 'Shirt', null, null, 50, '50 Ryo', null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('12 Guardian Waistcloth', 'roupa', 'A Waistcloth that members of the 12 Guardians wear to show their status. It grants the wearer +10 to all stats when equipped. You are required to have a level of 25 or above to wear this Item. You can obtain it by purchasing it from the 12 Guardians vendor for 100 Ryo. It drops on death.', 'Accessory', 'Event', 25, 100, '100 Ryo', 'NPC: 12 Guardians Equipment Vendor', null),
  ('Black Masked Top', 'roupa', 'A Black Sleeveless Top that will cover your nose and mouth. However, it does not conceal the identity of the wearer. You can obtain it by defeating Chei, who you can find within the Bandit Encampment.', 'Shirt', 'Rare', null, null, null, 'NPC: Chei', null),
  ('ANBU Greaves', 'roupa', 'Sleeves with armor plating attached to them providing additional protection. They are worn on the forearm and used to deflect swords and throwing weapons. You are required to have a level of 30 or above to utilize this item. You can obtain them from the Leaf ANBU Equipment Shop for the price of 2,500 Ryo. Only members of the Leaf Village ANBU can wear this item.', 'Accessory', 'Rare', null, 2500, '2,500 Ryo', 'Leaf ANBU Equipment Shop', null),
  ('ANBU Mask', 'roupa', 'A Mask that members of the Leaf Village ANBU wear. It protects the facial area and is also a means to conceal their identities. Each one is designed based on a specific animal. These consist of a Fox, a Dog, a Wolf, a Cat, and a Bird. It is the highlight of the set because, aside from hiding the user''s identity, it also gives each member their own unique identity. You are required to have a level of 5 or above to utilize this item. You can obtain them from the Leaf ANBU Equipment Shop for the price of 1,500 Ryo. Only members of the Leaf Village ANBU can wear this item.', 'Mask', 'Enchanted', 5, 1500, '1,500 Ryo', 'Leaf ANBU Equipment Shop', null),
  ('Arms Bandages', 'roupa', 'Tattered dressings that are wrapped around both arms. You can obtain this item by defeating the Bandit Boss Nelinel as a rare drop which is a 1% rating. You can sell this item in shops for 750 Ryo in shops and it goes on the accessory slot of your character.', 'Accessory', 'Uncommon', 5, null, null, 'NPC: Nelinel', null),
  ('Black Blindfold', 'roupa', 'A black blindfold covering your eyes. Very Nier.Designed by Fuze. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Bandage Face Mask', 'roupa', 'A bandage that wraps around your face as a mask. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Mask slot of your character.', 'Accessory', 'Premium', null, null, '$9.90 ($8,90 if Gold Member)', 'Cash Shop', null),
  ('Black Oni Half Mask', 'roupa', 'A half mask designed after the image of an Oni (Demon) that goes over your nose and mouth Mask item slot. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Black Cursed Sakkat', 'roupa', 'A black, hardwood sakkat that has a small cursed pendant on it''s side. Due to how old it is, hair tends to stick through it. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Hat slot of your character.', 'Hat', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Beige Hyu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Black Hermit Cape', 'roupa', 'This cosmetic item cape thrown over the right arm, revealing a purple inner lacing. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Black Hashi Uniform', 'roupa', 'This is a cosmetic item is a classic Gakuran Uniform. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Black Sasu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Beaded Necklace', 'roupa', 'A rare accessory that make you bald when wearing its.', 'Accessory', null, 20, null, '250 ryo to NPC', 'NPC: Gang Brawler rare drop', 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('3 Hair Color Matching Beards', 'roupa', 'A set of beards that match common hair colors, allowing players to customize their character''s facial hair.', 'Accessory', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Black Katahada Kimono', 'roupa', 'A traditional kimono in black, featuring the katahada style where one shoulder is exposed.', 'Outfit', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Black Cowl', 'roupa', 'A dark hooded cowl that gives a mysterious, shadowy appearance.', 'Outfit', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Alien Parasite Hat', 'roupa', 'A spooky hat that looks like an alien parasite attached to your head. A seasonal cosmetic available during the Halloween event.', 'Hat', 'Event', null, null, null, 'Halloween Event', null),
  ('Black Tenegui Towel Hat', 'roupa', 'Black Tenegui Towel Hat is a Common cosmetic hat. In game the item card names it simply "Black Tenegui Towel", without "Hat". Its description reads:', 'Hat', 'Common', 25, null, null, 'Weaving', null),
  ('Blight Leechskin Scarf', 'roupa', 'A scarf crafted from blight leech skin. This accessory can be crafted through Weaving at level 11.', 'Accessory', 'Crafted', 11, null, null, 'Weaving', null),
  ('Black High Heel Boots', 'roupa', 'Stylish black high heel boots. This footwear can be crafted through Weaving at level 19.', 'Footwear', 'Crafted', 19, null, null, 'Weaving', null),
  ('Black Adventure Cloak', 'roupa', 'Black Adventure Cloak is one of the colour variants of the Adventure Cloak. It provides no stat bonuses and is worn purely for appearance.', 'Cape', null, null, null, null, null, null),
  ('Backwards Cap', 'roupa', 'The Backwards Cap is a head cosmetic added to the Cash Shop in the 2026-07-11 patch. Backward Caps come in multiple colours.', 'Cosmetic', null, null, null, null, 'Cash Shop', null),
  ('Black Camo Top', 'roupa', 'Black Camo Top is a cosmetic shirt obtained from the War Event. Its in-game description reads:', 'Shirt', 'Event', null, null, '100 War Tokens', 'War Event', null),
  ('Black War Mantle', 'roupa', 'Black War Mantle is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '300 War Tokens', 'War Event', null),
  ('Black Ragged Poncho', 'roupa', 'Black Ragged Poncho is a cosmetic vest obtained from the War Event. It is a dark-grey version of the Ragged Poncho sold by Rachi in the Takumi Village Clothing Store, cut with the same pointed, layered hem. See Ragged Poncho for every known colour.', 'Vest', 'Event', null, null, null, 'War Event', null),
  ('Black Eye Patch', 'roupa', 'Black Eye Patch is an Event cosmetic mask. Its in-game description reads:', 'Mask', 'Event', 15, null, null, null, null),
  ('Black Formal Suit', 'roupa', 'The Black Formal Suit is a Common class cosmetic worn in the Shirt slot. Its in-game description reads:', 'Shirt', 'Common', 46, null, null, null, null),
  ('Black Formal Pants', 'roupa', 'The Black Formal Pants is a Common class cosmetic worn in the Pants slot. Its in-game description reads:', 'Pants', 'Common', 46, null, null, null, null),
  ('Bear Hood', 'roupa', 'The Bear Hood is a Rare class cosmetic worn in the Hat slot. Its in-game description reads:', 'Hat', 'Rare', 20, null, null, null, null),
  ('Black Bear Hood', 'roupa', 'The Black Bear Hood is a Legendary class cosmetic worn in the Hat slot. Its in-game description reads:', 'Hat', 'Legendary', null, null, null, null, null),
  ('Anniversary Spiral Mask', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Hat', 'Legendary', null, null, null, null, null),
  ('Black Compact Backpack', 'roupa', 'The Black Compact Backpack is a Uncommon class cosmetic worn in the Accessory slot. Its in-game description reads:', 'Accessory', 'Uncommon', null, null, null, null, null),
  ('Black Backpack', 'roupa', 'Part of the Backpack family. See that page for every variant side by side.', 'Accessory', 'Uncommon', null, null, null, null, null),
  ('Anniversary Furred Armor', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Vest', 'Legendary', null, null, null, null, null),
  ('Black Flak Jacket', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Vest', 'Uncommon', 5, null, null, null, null),
  ('Black Trash Lid Hat', 'roupa', 'The Black Trash Lid Hat is a Rare class cosmetic worn in the Hat slot, requiring Lv. 20. Its in-game description reads:', 'Hat', 'Rare', 20, null, null, null, null),
  ('Batsy Wings', 'roupa', 'Batsy Wings is a cosmetic accessory sold at the Halloween Shop in Haunted Hollow for 700 Halloween Token. Its in-game description has not been recorded yet. It is marked Exclusive to Halloween Events and was added in Update v6.', 'Accessory', null, null, null, null, 'Halloween Shop, Haunted Hollow (700 Halloween Token)', null),
  ('Black Ragged Robe', 'roupa', 'Black Ragged Robe is a cosmetic vest sold at the Halloween Shop in Haunted Hollow for 500 Halloween Token. The in-game description reads: "A ragged but still stylish robe!" Its palette was fixed in Update v6.0.0.3 (21 September 2026). It is marked Exclusive to Halloween Events and was added in Update v6.', 'Vest', null, null, null, null, 'Halloween Shop, Haunted Hollow (500 Halloween Token)', null),
  ('Black Straw Hat', 'roupa', 'Black Straw Hat is a cosmetic hat sold at the Halloween Shop in Haunted Hollow for 125 Halloween Token. Its in-game description has not been recorded yet. It is marked Exclusive to Halloween Events and was added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow (125 Halloween Token)', null),
  ('Ceramic War Armor', 'roupa', 'A limited edition war armor made of white ceramic. This item is no longer attainable and only was for the month of June 2017 . The cost of one was $10 or $9 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$10 ($9 if Gold Ninja)', 'Cash Shop', null),
  ('Chest Bandages', 'roupa', 'A bandage most commonly worn by women around the chest area. Only dropped by Kumorui.', 'Shirt', null, 5, null, null, 'NPC: Kumorui', null),
  ('Dojo Shirt', 'roupa', 'A new dojo shirt wear by a far away member of an old dojo school.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7,10 if Gold Member)', 'Cash Shop', null),
  ('Dojo Pants', 'roupa', 'A new dojo pants wear by a far away member of an old dojo school. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Pants slot of your character.', 'Pants', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Dark Blue Cursed Mark Tattoo', 'roupa', 'Markings on the wearer''s face. Face paints/markings are worn on the Mask item slot. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Blood Medic Mask', 'roupa', 'A mask that goes over your nose and mouth. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Blue Hashi Overcoat', 'roupa', 'This is a cosmetic item is a plain white overcoat. Can be worn over any shirt and pants, but made to match other items in the Hashi Set.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Blue Hyu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Blue Sasu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Blood Visor', 'roupa', 'A translucent visor to see the ninja world through. It comes in the colors Clear, Orange, Yellow, Green, Teal, Blue, Purple, Pink, and Red. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4.40 if Gold Ninja)', 'Cash Shop', null),
  ('Cat Ear Bucket Hats', 'roupa', 'A cute bucket hat with cat ears attached. A popular cosmetic for players who enjoy playful accessories.', 'Hat', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Burnt Bandage Head Wraps', 'roupa', 'Head wraps made of burnt bandages, giving a battle-worn appearance.', 'Accessory', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Colored Caps', 'roupa', 'Baseball-style caps available in multiple colors.', 'Hat', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Blue Katahada Kimono', 'roupa', 'A traditional kimono in blue, featuring the katahada style where one shoulder is exposed.', 'Outfit', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Elf Socks', 'roupa', 'Festive socks with an elf-themed design. A seasonal cosmetic available during the Christmas event. You can acquire this from the Christmas Shop using event coupons.', 'Accessory', 'Event', null, null, null, 'Christmas Shop', null),
  ('Ceremonial Neko Mask', 'roupa', 'A decorative cat-themed mask with ceremonial designs. A seasonal cosmetic available during the Christmas event. You can acquire this from the Christmas Shop using event coupons.', 'Hat', 'Event', null, null, null, 'Christmas Shop', null),
  ('Blue Tenegui Towel Hat', 'roupa', 'A traditional towel hat in blue, worn as headwear. This cosmetic can be crafted through Weaving at level 9.', 'Hat', 'Crafted', 9, null, null, 'Weaving', null),
  ('Crimson Leechskin Scarf', 'roupa', 'A scarf crafted from crimson leech skin. This accessory can be crafted through Weaving at level 12.', 'Accessory', 'Crafted', 12, null, null, 'Weaving', null),
  ('Blue Striped Bucket Hat', 'roupa', 'A bucket hat with blue stripes. This cosmetic can be obtained as a drop from mobs.', 'Hat', 'Drop', null, null, null, 'Mob Drop', null),
  ('Blurry Glasses', 'roupa', 'A pair of glasses with blurry lenses. This cosmetic can be purchased from the Glasses Shop.', 'Accessory', 'Common', null, null, null, 'Glasses Shop', null),
  ('Blue Adventure Cloak', 'roupa', 'Blue Adventure Cloak is one of the colour variants of the Adventure Cloak. It provides no stat bonuses and is worn purely for appearance.', 'Cape', null, null, null, null, null, null),
  ('Dark Veiled Sakkat', 'roupa', 'The Dark Veiled Sakkat is a darker variant of the Veiled Sakkat — a Sakkat with a veil, commonly used by missing-nin to conceal their identities. It was added in update v5.13.0 and provides no stat bonuses. It is a crafted item — see Acquisition below.', 'Headwear', null, null, null, null, null, null),
  ('Blue Camo Top', 'roupa', 'Blue Camo Top is a cosmetic shirt obtained from the War Event. Its in-game description reads:', 'Shirt', 'Event', null, null, '100 War Tokens', 'War Event', null),
  ('Dark War Robe', 'roupa', 'Dark War Robe is a cosmetic shirt obtained from the War Event. Its in-game description reads:', 'Shirt', 'Event', null, null, '400 War Tokens', 'War Event', null),
  ('Dark War Tunic', 'roupa', 'Dark War Tunic is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '300 War Tokens', 'War Event', null),
  ('Dark War Armor', 'roupa', 'Dark War Armor is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '500 War Tokens', 'War Event', null),
  ('Blue War Headband', 'roupa', 'Blue War Headband is a cosmetic headwear item obtained from the War Event. Its in-game description reads:', 'Hat', 'Event', null, null, '150 War Tokens', 'War Event', null),
  ('Dark War Sakkat', 'roupa', 'Dark War Sakkat is a cosmetic headwear item obtained from the War Event. Its in-game description reads:', 'Hat', 'Event', null, null, '200 War Tokens', 'War Event', null),
  ('Dark War Neko Mask', 'roupa', 'Dark War Neko Mask is a cosmetic headwear item obtained from the War Event. Its in-game description reads:', 'Hat', 'Event', null, null, '150 War Tokens', 'War Event', null),
  ('Blue Masked Top', 'roupa', 'A Blue Masked Top is a cosmetic shirt. Its in-game description reads:', 'Shirt', 'Unique', null, null, null, 'NPC: Mother Crystal Slug', null),
  ('Blue War Mantle', 'roupa', 'Blue War Mantle is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '300 War Tokens', 'War Event', null),
  ('Dark Barbarian Cloak', 'roupa', 'Dark Barbarian Cloak is the dark colour variant of the Barbarian Cloak, a Legendary cosmetic vest. It occupies the Vest slot, has no level or stat requirement, and gives no stat bonuses.', 'Vest', 'Legendary', null, null, null, null, null),
  ('Blue Halo', 'roupa', 'The Blue Halo is a Premium cosmetic worn in the Hat slot. It floats above the character''s head rather than sitting on it. Its in-game description reads:', 'Hat', 'Premium', null, null, null, null, null),
  ('Blue Fighter Pants', 'roupa', 'The Blue Fighter Pants is a Uncommon class cosmetic worn in the Pants slot. Its in-game description reads:', 'Pants', 'Uncommon', null, null, null, null, null),
  ('Cha Shu Ramen Hat', 'roupa', 'The Cha Shu Ramen Hat is a Common class cosmetic worn in the Hat slot. Its in-game description reads:', 'Hat', 'Common', null, null, null, null, null),
  ('Blue Poncho', 'roupa', 'Part of the Poncho family. See that page for every variant side by side.', 'Vest', 'Rare', null, null, null, null, null),
  ('Brown Bandit Mask', 'roupa', 'The Brown Bandit Mask is a Unique cosmetic worn in the Mask slot. Its in-game description reads:', 'Mask', 'Unique', null, null, null, null, null),
  ('Brown Bear Jacket', 'roupa', 'Brown Bear Jacket is an Uncommon cosmetic vest. Its in-game description reads:', 'Vest', 'Uncommon', null, null, null, null, null),
  ('Blue Jira Vest', 'roupa', 'Part of the Jira Vest family. See that page for every variant side by side.', 'Vest', 'Event', 30, null, '75 Event Coupons', 'Takumi Village Special Event House — NPC: Guchi & Gutari', null),
  ('Blue Nuo Mask', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Hat', 'Event', 25, null, null, null, null),
  ('Christmas Hanzo Mask', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Hat', 'Event', null, null, null, null, null),
  ('Clown Mask', 'roupa', 'Clown Mask is a cosmetic mask sold at the Halloween Shop in Haunted Hollow for 200 Halloween Token. The in-game description reads: "A creepy mask of a clown face." It is marked Exclusive to Halloween Events and was added in Update v6.', 'Mask', null, null, null, null, 'Halloween Shop, Haunted Hollow (200 Halloween Token)', null),
  ('Curved Devil Horns', 'roupa', 'Curved Devil Horns is a cosmetic hat sold at the Halloween Shop in Haunted Hollow for 200 Halloween Token. The in-game description reads: "A Halloween costume, these almost look like real horns!" It is marked Exclusive to Halloween Events and was added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow (200 Halloween Token)', null),
  ('Creepy Doll Mask', 'roupa', 'Creepy Doll Mask is a cosmetic mask sold at the Halloween Shop in Haunted Hollow for 125 Halloween Token. The in-game description reads: "This porcelain doll mask conceals more than a face. Faint scratches on its surface hint that it was never meant to be worn." It is marked Exclusive to Halloween Events and was added in Update v6.', 'Mask', null, null, null, null, 'Halloween Shop, Haunted Hollow (125 Halloween Token)', null),
  ('Brown Cowboy Hat', 'roupa', 'Brown Cowboy Hat is a cosmetic hat sold at the Halloween Shop in Haunted Hollow for 125 Halloween Token. The in-game description reads: "Nobody really knows what a Cowboy is, but if there were Cowboys around, this is probably what they would wear." Its visuals were reworked, along with every other Cowboy Hat colour, and its palette fixed in Update v6.0.0.3 (21 September 2026). It is marked Exclusive to Halloween Events and was added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow (125 Halloween Token)', null),
  ('Devil Horns', 'roupa', 'Devil Horns is a set of 5 cosmetic hat variants sold at the Halloween Shop in Haunted Hollow. The in-game description reads: "These little horns stick out of your hair giving you power, or so people say." All variants are marked Exclusive to Halloween Events and were added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow', null),
  ('Devil Wings', 'roupa', 'Devil Wings is a set of 2 cosmetic accessory variants sold at the Halloween Shop in Haunted Hollow. The in-game description reads: "A Halloween costume, this is actually just rubber, but it looks very threatening!" All variants are marked Exclusive to Halloween Events and were added in Update v6.', 'Accessory', null, null, null, null, 'Halloween Shop, Haunted Hollow', null),
  ('Forehead Protector', 'roupa', 'A Forehead Protector is most essential piece of any ninja''s standard uniform. The forehead protector is a sign of mutual respect as ninjas in combat. It is also the first item in Nin Online which gives you any form statistic bonus.', 'Mask', null, null, null, 'Academy Graduation Slip', null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Hooded Robes', 'roupa', 'A colored robe which covers most of the body and has a hood over the head. Comes in the colors Red, Blue, Tan, White, Teal, and Black. You acquire it from the Takumi Village prize shop. The cost of one is 10 Event Coupons and it goes in the Vest slot of your character.', 'Vest', 'Event', null, null, '10 Event Coupons', 'Takumi Village Special Event House', null),
  ('Gloves Knuckle', 'roupa', 'The Gloves Knuckle is a pair of iron plated black gloves. It''s supposed to make you hit harder but it''s mainly used for fashion and showing off. They are currently dropped by the bandit Reain.', 'Accessory', 'Unique', null, null, null, 'NPC: Reain', null),
  ('Jira Vest', 'roupa', 'A sage-like sleeveless garment worn over your shirt with a scroll hanging from the back. It''s typically worn by wandering sages and hermits. Goes surprisingly well with the Hermit Forehead Protector. The Blue Jira Vest has a page of its own, written from its item card. You can obtain blue, pink and green variants from the Takumi Village prize shop for the price of 75 event coupons each. The red variant is only purchasable in the Cash Shop.', 'Vest', 'Event', 30, null, '75 Event Coupons', 'Takumi Village Special Event House — NPC: Guchi & Gutari', null),
  ('Gas Mask', 'roupa', 'A mask that protects the nose and mouth but does not conceal the user''s identity. This item can be obtained from Tause, who is located outside of the bandit encampment.', 'Mask', 'Common', null, null, null, 'NPC: Tause', null),
  ('Face Mask', 'roupa', 'A mask that goes over your nose and mouth. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Kanku Face Paint Pink', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Kanku Face Paint Green', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Kanku Face Paint Blue', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Kanku Face Paint Red', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Justice Cape', 'roupa', 'This is a cosmetic item is a white jacket with shoulder paddings, worn hung over the arms like a cape. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Gray Wanderers Scarf', 'roupa', 'This is a cosmetic item is a scarf worn around the neck and covering half of the user''s face. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 7,90 or $7.10 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$7,90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Green Hashi Uniform', 'roupa', 'This is a cosmetic item is a classic Gakuran Uniform. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Green Hashi Overcoat', 'roupa', 'This is a cosmetic item is a plain white overcoat. Can be worn over any shirt and pants, but made to match other items in the Hashi Set.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Green Hyu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Green Sasu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Green Visor', 'roupa', 'A translucent visor to see the ninja world through. It comes in the colors Clear, Orange, Yellow, Green, Teal, Blue, Purple, Pink, and Red. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4.40 if Gold Ninja)', 'Cash Shop', null),
  ('Hockey Mask', 'roupa', 'A mask worn for ice sports and murder. This mask hides the wearer''s identity.', 'Mask', null, null, null, null, null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Floppy Bunny Ears', 'roupa', 'Cute floppy bunny ears worn as a headband accessory.', 'Accessory', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Green Tenegui Towel Hat', 'roupa', 'Green Tenegui Towel Hat is a Common cosmetic hat. In game the item card names it simply "Green Tenegui Towel", without "Hat". Its description reads:', 'Hat', 'Common', 25, null, null, 'Weaving', null),
  ('Green Ducky Bucket Hat', 'roupa', 'A bucket hat with a green ducky design. A fun cosmetic hat for players who enjoy playful accessories.', 'Hat', 'Common', null, null, null, null, null),
  ('Flesh Mask', 'roupa', 'Flesh Mask is a cosmetic mask added as an Event Shop prize in update v5.11.1. It provides no stat bonuses.', 'Mask', 'Event', null, null, null, 'Event Shop', null),
  ('Green Adventure Cloak', 'roupa', 'Green Adventure Cloak is one of the colour variants of the Adventure Cloak. In the image below it is the cape worn on the right — the item on the left is a Twinfall Scarf. It provides no stat bonuses and is worn purely for appearance.', 'Cape', null, null, null, null, null, null),
  ('High Heel Boots', 'roupa', 'The High Heel Boots are cosmetic high-heeled boots crafted through Weaving. They give no stat bonuses and are worn purely for appearance, in the Shoes slot (Female characters only).', 'Footwear', 'Crafted', 18, null, null, 'Weaving', null),
  ('Kanku Face Paint', 'roupa', 'The Kanku Face Paint is a cosmetic face paint design. It comes in several colour variants and provides no stat bonuses, worn purely for appearance. Source: Cash Shop. Equipment type: Mask.', null, null, null, null, null, null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Geta Sandals', 'roupa', 'Geta Sandals go on your feet for comfort and protection against small threats like pebbles and lego pieces. They were added in the Land of Spirits Update (2026-07-04).', 'Shoes', 'Common', null, null, null, null, null),
  ('Green Camo Top', 'roupa', 'Green Camo Top is a cosmetic shirt obtained from the War Event. Its in-game description reads:', 'Shirt', 'Event', null, null, '100 War Tokens', 'War Event', null),
  ('Grey Barbarian Cloak', 'roupa', 'Grey Barbarian Cloak is a Legendary cosmetic vest. Its in-game description reads:', 'Vest', 'Legendary', null, null, null, null, null),
  ('Green Striped Bucket Hat', 'roupa', 'Green Striped Bucket Hat is a Rare cosmetic hat and the fourth known colour of the Striped Bucket Hat. Its in-game description reads:', 'Hat', 'Rare', null, null, null, 'Mob Drop', null),
  ('Jiangshi Hat', 'roupa', 'Jiangshi Hat is an Event class cosmetic hat. Its in-game description reads:', 'Hat', 'Event', null, null, null, null, null),
  ('Hunter Cloak', 'roupa', 'The Hunter Cloak is a cosmetic cloak awarded for reaching 600 Romaji kills, the final tier of the Hunter''s Call achievement track. It is the rarest of the three Romaji rewards and cannot be bought or traded for.', 'Vest', 'Legendary', null, null, 'Not sold (achievement reward)', 'Achievement reward', null),
  ('Hunter Scarf', 'roupa', 'The Hunter Scarf is a cosmetic mask awarded for reaching 300 Romaji kills, the second tier of the Hunter''s Call achievement track. It cannot be bought or traded.', 'Mask', 'Unique', null, null, 'Not sold (achievement reward)', 'Achievement reward', null),
  ('Hanging Sakkat', 'roupa', 'The Hanging Sakkat is a Common class cosmetic worn in the Hat slot. Its in-game description reads:', 'Hat', 'Common', null, null, null, null, null),
  ('Gold Oni Half Mask', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Mask', 'Event', null, null, null, null, null),
  ('Green Poncho', 'roupa', 'Part of the Poncho family. See that page for every variant side by side.', 'Vest', 'Rare', null, null, null, null, null),
  ('Green Sport Hoodie', 'roupa', 'Green Sport Hoodie is a Rare class cosmetic worn in the Vest slot. Its in-game description reads:', 'Vest', 'Rare', null, null, null, null, null),
  ('Green Jira Vest', 'roupa', 'Part of the Jira Vest family. See that page for every variant side by side.', 'Vest', 'Event', 30, null, '75 Event Coupons', 'Takumi Village Special Event House — NPC: Guchi & Gutari', null),
  ('Hyoketsu Military Cape', 'roupa', 'Hyoketsu Military Cape is a legendary vest dropped by Warden Haoya in Hyoketsu Prison. Its in-game description reads:', 'Vest', 'Legendary', null, null, null, null, null),
  ('Hyoketsu Military Shirt', 'roupa', 'Hyoketsu Military Shirt is a rare shirt dropped by Warden Haoya in Hyoketsu Prison. Its in-game description reads:', 'Shirt', 'Rare', null, null, null, null, null),
  ('Hyoketsu Military Pants', 'roupa', 'Hyoketsu Military Pants is a rare pants dropped by Warden Haoya in Hyoketsu Prison. Its in-game description reads:', 'Pants', 'Rare', null, null, null, null, null),
  ('Hyoketsu Military Cap', 'roupa', 'Hyoketsu Military Cap is a rare hat dropped by Warden Haoya in Hyoketsu Prison. Its in-game description reads:', 'Hat', 'Rare', null, null, null, null, null),
  ('Hellfire Skull Hat', 'roupa', 'Hellfire Skull Hat is a cosmetic hat sold at the Halloween Shop in Haunted Hollow for 1250 Halloween Token. The in-game description reads: "A skull hat forged in the depths of hell, eternally engulfed in demonic flames that hunger for flesh and soul." It is marked Exclusive to Halloween Events and was added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow (1250 Halloween Token)', null),
  ('Ghost Pal', 'roupa', 'Ghost Pal is a cosmetic accessory (moved from the hat slot to the accessory slot in Update v6.0.0.3 (21 September 2026)), originally a hat sold at the Halloween Shop in Haunted Hollow for 800 Halloween Token. The in-game description reads: "A friendly little ghost that follows you wherever you go, quietly drifting by your side with a hint of sadness in its eyes." It is marked Exclusive to Halloween Events and was added in Update v6.', 'Accessory', null, null, null, null, 'Halloween Shop, Haunted Hollow (800 Halloween Token)', null),
  ('Evil Cupid Wings', 'roupa', 'Evil Cupid Wings is a cosmetic accessory sold at the Halloween Shop in Haunted Hollow for 700 Halloween Token. The in-game description reads: "A halloween costume accessory, this is actually just rubber, but it looks very cute!" It is marked Exclusive to Halloween Events and was added in Update v6.', 'Accessory', null, null, null, null, 'Halloween Shop, Haunted Hollow (700 Halloween Token)', null),
  ('Fallen Angel Wings', 'roupa', 'Fallen Angel Wings is a cosmetic accessory sold at the Halloween Shop in Haunted Hollow for 500 Halloween Token. Its in-game description has not been recorded yet. It is marked Exclusive to Halloween Events and was added in Update v6.', 'Accessory', null, null, null, null, 'Halloween Shop, Haunted Hollow (500 Halloween Token)', null),
  ('Goblin Mask', 'roupa', 'Goblin Mask is a set of 2 cosmetic mask variants sold at the Halloween Shop in Haunted Hollow. The in-game description reads: "A cursed mask with eyes that burn with an eerie, otherworldly light. No one knows what lies behind its gaze." All variants are marked Exclusive to Halloween Events and were added in Update v6.', 'Mask', null, null, null, null, 'Halloween Shop, Haunted Hollow', null),
  ('Leg Bandages', 'roupa', 'Tattered dressings which are wrapped around the leg. You feel agile like mongoose! You can acquired it from the Clothing Shop that is located in Takumi Village. The cost of one is 250 Ryo and it goes in the footwear slot of your character. Or drop them the boss Kumorui.', 'Footwear', 'Common', 5, 250, '250 Ryo', 'Takumi Village Clothing Store — NPC: Kumorui', null),
  ('Ki Robes', 'roupa', 'A colored robe which covers most of the body and has a hood around the neck. You acquire it from the Event HQ which is located in Takumi Village. The cost of one is 10 Event Tickets and it goes in the Vest slot of your character.', 'Vest', 'Event', null, null, '10 Event Tickets', 'Takumi Village Special Event House', null),
  ('Ragged Poncho', 'roupa', 'A ragged poncho used to keep you comfortable in harsh weather environments. You can acquire it from the clothing shop that is located in Takumi Village. The cost of one is 4,000 Ryo and it goes in the Vest slot of your character. This page also covers the other poncho colours — see Variants below.', 'Vest', 'Uncommon', null, 4000, '4,000 Ryo', 'Takumi Village Clothing Store — NPC: Rachi', null),
  ('Raging Bandit Jacket', 'roupa', 'Raging Bandit Jacket is a Legendary class cosmetic worn in the Vest slot. Its in-game description reads:', 'Vest', 'Legendary', null, null, null, null, null),
  ('Raging Bandit Pants', 'roupa', 'A warm pair of fur pants worn by the bandits in the snowy area. It''s dropped by the bandit Takeshi. It''s a piece of the Raging Bandit outfit.', 'Pants', 'Legendary', null, null, null, 'NPC: Takeshi', null),
  ('Make Out Tactics', 'roupa', 'It''s an old book written by a ninja containing tactics of picking up ladies. It''s famously used by many young shinobi nowadays teaching them the secret techniques to every girls heart. You can buy your own copy from the Takumi Village event shop.', 'Accessory', 'Event', 21, null, '50 Event Coupons', 'Takumi Village Special Event House — NPC: Guchi and Gutari', null),
  ('Kiba Face Paint Pink', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Kiba Face Paint Green', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Kiba Face Paint Blue', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Kiba Face Paint Red', 'roupa', 'Markings on the wearer''s face. Face paints/markings/tattoos are worn on the Mask item slot You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Pink Hyu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Purple Sasu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Orange Visor', 'roupa', 'A translucent visor to see the ninja world through. It comes in the colors Clear, Orange, Yellow, Green, Teal, Blue, Purple, Pink, and Red. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4.40 if Gold Ninja)', 'Cash Shop', null),
  ('Poison Visor', 'roupa', 'A translucent visor to see the ninja world through. It comes in the colors Clear, Orange, Yellow, Green, Teal, Blue, Purple, Pink, and Red. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4.40 if Gold Ninja)', 'Cash Shop', null),
  ('Pumpkin Mask', 'roupa', 'A Pumpkin Mask is an Mask from Halloween Event that help conceal your identity', null, null, null, null, null, null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Phantom Mask', 'roupa', 'A mysterious mask that conceals the wearer''s identity with a phantom-like appearance.', 'Mask', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Party Dress', 'roupa', 'An elegant party dress available in 10 different colors. Perfect for special occasions and social events.', 'Outfit', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Pink Cowboy Hat', 'roupa', 'A stylish cowboy hat in pink. This cosmetic can be obtained from the Event Prize Shop using event coupons.', 'Hat', 'Event', null, null, null, 'Event Prize Shop', null),
  ('Pink Tenegui Towel Hat', 'roupa', 'A traditional towel hat in pink, worn as headwear. This cosmetic can be crafted through Weaving at level 11.', 'Hat', 'Crafted', 11, null, null, 'Weaving', null),
  ('Purple Tenegui Towel Hat', 'roupa', 'A traditional towel hat in purple, worn as headwear. This cosmetic can be crafted through Weaving at level 12.', 'Hat', 'Crafted', 12, null, null, 'Weaving', null),
  ('Puppet Mask', 'roupa', 'A decorative mask with a puppet-like appearance. This cosmetic can be crafted through Weaving once you obtain the recipe from mob drops.', 'Mask', 'Recipe Drop', null, null, null, 'Weaving', null),
  ('Maki Sushi Hat', 'roupa', 'A fun hat shaped like maki sushi rolls. This cosmetic can be crafted through Weaving once you obtain the recipe from mob drops.', 'Hat', 'Recipe Drop', null, null, null, 'Weaving', null),
  ('Orange Striped Bucket Hat', 'roupa', 'A bucket hat with orange stripes. This cosmetic can be obtained as a drop from mobs.', 'Hat', 'Drop', null, null, null, 'Mob Drop', null),
  ('Leaf Utility Vest', 'roupa', 'A utility vest for Leaf Village ninja. This cosmetic can be purchased from the Accessories Shop at the Night Market.', 'Vest', 'Common', null, null, null, 'Accessories Shop', null),
  ('Mist Medical Unit Shirt', 'roupa', 'A shirt exclusive to members of the Mist Village Medical Corps. This outfit identifies the wearer as a trained medical ninja serving their village.', 'Outfit', 'Common', null, null, null, 'Medical Corps', null),
  ('Purple Adventure Cloak', 'roupa', 'Purple Adventure Cloak is one of the colour variants of the Adventure Cloak. It provides no stat bonuses and is worn purely for appearance.', 'Cape', null, null, null, null, null, null),
  ('Kiba Face Paint', 'roupa', 'The Kiba Face Paint is a cosmetic face paint design. It comes in several colour variants and provides no stat bonuses, worn purely for appearance. Source: Cash Shop. Equipment type: Mask.', null, null, null, null, null, null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Kasa Sakkat', 'roupa', 'Kasa Sakkat is a strange yokai sakkat that faintly rustles like a living umbrella. It was added in the Land of Spirits Update (2026-07-04).', 'Hat', 'Rare', null, null, null, null, null),
  ('Purple War Mantle', 'roupa', 'Purple War Mantle is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '300 War Tokens', 'War Event', null),
  ('Purple War Headband', 'roupa', 'Purple War Headband is a cosmetic headwear item obtained from the War Event. Its in-game description reads:', 'Hat', 'Event', null, null, '150 War Tokens', 'War Event', null),
  ('Raging Hermit Shirt', 'roupa', 'Raging Hermit Shirt is a Legendary cosmetic shirt dropped by Keldo. Its in-game description reads:', 'Shirt', 'Legendary', null, null, null, 'NPC: Keldo', null),
  ('Pink Bamboo Hat', 'roupa', 'Pink Bamboo Hat is a cosmetic hat and the seventh known colour of the Bamboo Hat. Its item card is classed Event and its in-game description reads:', 'Hat', 'Event', null, null, null, null, null),
  ('Leaf Council Robe', 'roupa', 'The Leaf Council Robe is a Legendary cosmetic worn in the Vest slot, restricted to Leaf Village and requiring Lv. 40. Its in-game description reads:', 'Vest', 'Legendary', 40, null, null, null, null),
  ('Prowler Pants', 'roupa', 'The Prowler Pants is a Rare class cosmetic worn in the Pants slot. Its in-game description reads:', 'Pants', 'Rare', null, null, null, null, null),
  ('Poisony Pants', 'roupa', 'The Poisony Pants is a Unique class cosmetic worn in the Pants slot. Its in-game description reads:', 'Pants', 'Unique', 10, null, null, null, null),
  ('Purple Oni Half Mask', 'roupa', 'Part of the Oni Half Mask family. See that page for every variant side by side.', 'Mask', 'Rare', 30, null, null, null, null),
  ('Purple Snake Rope Belt', 'roupa', 'The Purple Snake Rope Belt is a Rare class cosmetic worn in the Accessory slot. Its in-game description reads:', 'Accessory', 'Rare', null, null, null, null, null),
  ('Mizukami Cloak', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Vest', 'Legendary', null, null, null, null, null),
  ('Mizukami Hat', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Hat', 'Legendary', null, null, null, null, null),
  ('Mist Special Division Mask', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Hat', 'Enchanted', 5, null, null, null, null),
  ('Mist Special Division Robe', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Vest', 'Common', null, null, null, null, null),
  ('Purple War Armor', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Vest', 'Legendary', null, null, null, null, null),
  ('Prison Shirt', 'roupa', 'Prison Shirt is a Common cosmetic shirt sold by the Prison Outfits vendor inside Hyoketsu Prison. Its in-game description reads:', 'Shirt', 'Common', null, null, null, null, null),
  ('Prison Pants', 'roupa', 'Prison Pants is a Common cosmetic pants item sold by the Prison Outfits vendor inside Hyoketsu Prison. Its in-game description reads:', 'Pants', 'Common', null, null, null, null, null),
  ('Pumpkin Coat', 'roupa', 'Pumpkin Coat is a cosmetic vest sold at the Halloween Shop in Haunted Hollow for 3000 Halloween Token. The in-game description reads: "A festive coat inspired by the spirit of Halloween, perfect for wandering through the night of tricks, treats, and spooky celebrations." It is marked Exclusive to Halloween Events and was added in Update v6.', 'Vest', null, null, null, null, 'Halloween Shop, Haunted Hollow (3000 Halloween Token)', null),
  ('Scarfed Sand Robe', 'roupa', 'A sand robe that can be bought in the clothing shop by Mako for 2,500 Ryo.', 'Vest', null, null, null, '2,500', null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Scarfed Black Robe', 'roupa', 'A black sand colored robe which covers most of the body, and has a large scarf around the', 'Vest', null, null, null, '2,500', null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Scarfed Robe', 'roupa', 'The Scarfed Robe is a cosmetic robe with an attached scarf, available in different colours. It provides no stat bonuses and is worn purely for appearance. Source: Information needed. Equipment type: Vest.', null, null, null, null, null, null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Sashed Kimono', 'roupa', 'A traditional Japanese garment. Comes in the colors Blue, Red, Green, Sea Blue, Beige, Purple, Gray, Black, and White. You acquire it from the Takumi Village event shop. The cost of one is 20 Event Coupons and it goes in the Shirt slot of your character.', 'Shirt', 'Event', 30, null, '20 Event Coupons', 'Takumi Village Special Event House — NPC: Guchi & Gutari', null),
  ('Sakkat', 'roupa', 'A Sakkat, commonly used by missing-ninja to hide their identities. You acquired this from the Clothing Shop that is located in Takumi Village. The cost of one is 2,500 Ryo and it goes in the Headwear slot of your character.', 'Headwear', null, null, 2500, '2,500 Ryo', 'Takumi Clothing II — NPC: Rachi', null),
  ('Red Scarf', 'roupa', 'Red scarf for cold days.', 'Mask', null, 5, null, null, 'NPC: Nelinel', null),
  ('Sashed Baggy Pants', 'roupa', 'The Sashed Baggy pants is a pair of pants dropped by the bandit Kiemon. It''s a pair of baggy pants with an attached red sash below the waist, they are loose and baggy for optimal movement but also to keep the wearer warm in the snow.', 'Pants', 'Common', null, null, null, 'NPC: Kiemon', null),
  ('Red Curse Mark Tattoo', 'roupa', 'Markings on the wearer''s face. Face paints/markings are worn on the Mask item slot. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Sasu Robe', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Red Jira Vest', 'roupa', 'This cosmetic item is a sage garment worn over your shirt, with a scroll hanging on the back.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Red Hashi Uniform', 'roupa', 'This is a cosmetic item is a classic Gakuran Uniform. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Red Hashi Overcoat', 'roupa', 'This is a cosmetic item is a plain white overcoat. Can be worn over any shirt and pants, but made to match other items in the Hashi Set.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Red Sasu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Sakura Visor', 'roupa', 'A translucent visor to see the ninja world through. It comes in the colors Clear, Orange, Yellow, Green, Teal, Blue, Purple, Pink, and Red. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4.40 if Gold Ninja)', 'Cash Shop', null),
  ('Sand War Armor', 'roupa', 'Decorative armor inspired by Sand Village military designs.', 'Armor', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Rat Pal', 'roupa', 'A small rat companion that follows your character around. This cosmetic pet does not provide any combat benefits.', 'Pet', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Santa Beard', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Mask', 'Event', null, null, null, null, null),
  ('Rainbow Cap', 'roupa', 'A colorful cap featuring rainbow colors. This cosmetic can be obtained from the Event Prize Shop using event coupons.', 'Hat', 'Event', null, null, null, 'Event Prize Shop', null),
  ('Red Tenegui Towel Hat', 'roupa', 'Red Tenegui Towel Hat is a Common cosmetic hat. In game the item card names it simply "Red Tenegui Towel", without "Hat". Its description reads:', 'Hat', 'Common', 25, null, null, 'Weaving', null),
  ('Slugskin Scarf', 'roupa', 'A scarf crafted from slug skin. This accessory can be crafted through Weaving at level 13.', 'Mask', 'Uncommon', 5, null, null, 'Weaving', null),
  ('Red High Heel Boots', 'roupa', 'Stylish red high heel boots. This footwear can be crafted through Weaving at level 18.', 'Footwear', 'Crafted', 18, null, null, 'Weaving', null),
  ('Red Striped Bucket Hat', 'roupa', 'A bucket hat with red stripes. This cosmetic can be obtained as a drop from mobs.', 'Hat', 'Drop', null, null, null, 'Mob Drop', null),
  ('Romaji Bandit Pants', 'roupa', 'Pants worn by Romaji. This cosmetic can be obtained as a drop from Romaji.', 'Outfit', 'Drop', null, null, null, null, null),
  ('Sashiba Jacket', 'roupa', 'A jacket worn by members of the Sashiba Clan in Sand Village. This cosmetic can be purchased from the Sashiba Clan House.', 'Outfit', 'Clan', 30, null, null, 'Sashiba Clan House', null),
  ('Sashiba Pants', 'roupa', 'Pants worn by members of the Sashiba Clan in Sand Village. This cosmetic can be purchased from the Sashiba Clan House.', 'Outfit', 'Clan', 30, null, null, 'Sashiba Clan House', null),
  ('Sashiba Scarf', 'roupa', 'A scarf worn by members of the Sashiba Clan in Sand Village. This cosmetic can be purchased from the Sashiba Clan House.', 'Accessory', 'Clan', 30, null, null, 'Sashiba Clan House', null),
  ('Sand Ragged Cape', 'roupa', 'Sand Ragged Cape is a cosmetic cape added to the Cash Shop in update v5.13.0 (art by Luu). It provides no stat bonuses and is worn purely for appearance.', 'Cape', 'Cash', null, null, null, 'Cash Shop', null),
  ('Red Adventure Cloak', 'roupa', 'Red Adventure Cloak is one of the colour variants of the Adventure Cloak. It provides no stat bonuses and is worn purely for appearance.', 'Cape', null, null, null, null, null, null),
  ('Red Cursed Sakkat', 'roupa', 'Red Cursed Sakkat is a cosmetic hat added in update v5.12.7h. It is a recolor (by Luhan) sold in the Cash Shop for 890 NC. It provides no stat bonuses and is worn purely for appearance.', 'Hat', null, null, null, null, 'Cash Shop (890 NC)', null),
  ('Red Forsaken Exile Robe', 'roupa', 'Red Forsaken Exile Robe is a cosmetic body outfit added in update v5.12.7h. It is a recolor (by Luhan) sold in the Cash Shop for 890 NC. It provides no stat bonuses and is worn purely for appearance.', 'Vest', null, null, null, null, 'Cash Shop (890 NC)', null),
  ('Red Futago no Rantan', 'roupa', 'Red Futago no Rantan is a set of haunted lanterns that float at your side, their yokai flame never fading. It was added in the Land of Spirits Update (2026-07-04).', 'Accessory', 'Unique', null, null, null, null, null),
  ('Red Camo Top', 'roupa', 'Red Camo Top is a cosmetic shirt obtained from the War Event. Its in-game description reads:', 'Shirt', 'Event', null, null, '100 War Tokens', 'War Event', null),
  ('Red War Robe', 'roupa', 'Red War Robe is a cosmetic shirt obtained from the War Event. Its in-game description reads:', 'Shirt', 'Event', null, null, '400 War Tokens', 'War Event', null),
  ('Red War Mantle', 'roupa', 'Red War Mantle is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '300 War Tokens', 'War Event', null),
  ('Red War Tunic', 'roupa', 'Red War Tunic is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '300 War Tokens', 'War Event', null),
  ('Red War Headband', 'roupa', 'Red War Headband is a cosmetic headwear item obtained from the War Event. Its in-game description reads:', 'Hat', 'Event', null, null, '150 War Tokens', 'War Event', null),
  ('Red War Sakkat', 'roupa', 'Red War Sakkat is a cosmetic headwear item obtained from the War Event. Its in-game description reads:', 'Hat', 'Event', null, null, '200 War Tokens', 'War Event', null),
  ('Red Poncho', 'roupa', 'Red Poncho is a cosmetic vest. It is a red version of the Ragged Poncho sold by Rachi in the Takumi Village Clothing Store, cut with the same pointed, layered hem that sweeps to a point below the knee. See Ragged Poncho for every known colour.', 'Vest', 'Rare', null, null, null, null, null),
  ('Root Forehead Protector', 'roupa', 'Root Forehead Protector is an Event class cosmetic worn in the Mask slot. Its in-game description reads:', 'Mask', 'Event', null, null, null, null, null),
  ('Sand Police Vest', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Vest', 'Common', null, null, null, null, null),
  ('Red Formal Suit', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Shirt', 'Event', null, null, null, null, null),
  ('Red Backpack', 'roupa', 'Part of the Backpack family. See that page for every variant side by side.', 'Accessory', 'Uncommon', null, null, null, null, null),
  ('Skull Mask', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Mask', 'Event', null, null, null, null, null),
  ('Rich Cap', 'roupa', 'Rich Cap is an Uncommon cosmetic hat. Its in-game description reads:', 'Hat', 'Uncommon', null, null, null, null, null),
  ('Scary Jester Hood', 'roupa', 'Scary Jester Hood is a cosmetic hat sold at the Halloween Shop in Haunted Hollow for 1000 Halloween Token. Its in-game description has not been recorded yet. It is marked Exclusive to Halloween Events and was added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow (1000 Halloween Token)', null),
  ('Scary Hockey Mask', 'roupa', 'Scary Hockey Mask is a cosmetic mask sold at the Halloween Shop in Haunted Hollow for 200 Halloween Token. The in-game description reads: "A worn hockey mask that hides all emotion behind cold eyeholes. It carries an unsettling silence wherever it goes." It is marked Exclusive to Halloween Events and was added in Update v6.', 'Mask', null, null, null, null, 'Halloween Shop, Haunted Hollow (200 Halloween Token)', null),
  ('Scarecrow Hat', 'roupa', 'Scarecrow Hat is a set of 5 cosmetic hat variants sold at the Halloween Shop in Haunted Hollow. The in-game description reads: "A weathered scarecrow hat with a crooked top, carrying an spooky presence wherever it is worn." All variants are marked Exclusive to Halloween Events and were added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow', null),
  ('Spiral Mask', 'roupa', 'An orange spiral mask with only a single hole for the wearer''s eye. When putting this on it hides your identity from other ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $10 or $9 if you are a gold member and it goes in the Headwear slot of your character.', 'Headwear', 'Premium', null, null, '$10 ($9 if Gold Ninja)', 'Cash Shop', null),
  ('Snake Rope Belt', 'roupa', 'Snake Rope Belt is an unique accessory item which is obtainable either by defeating Manda or Koitaru.', 'Accessory', 'Unique', null, null, null, 'NPC: Manda', null),
  ('Tales of a Gutsy Ninja', 'roupa', 'The first not so famous old book written of a legendary Shinobi written long time ago. Tells the story of a young ninja.', 'Accessory', 'Rare', 13, null, null, 'NPC: Raccoon Bandit', null),
  ('Veiled Sakkat', 'roupa', 'A Sakkat with a veil, commonly used by missing-nin to hide their identities. To acquire this item you must have Benkei, the requirements to craft them are: Completed ''Benkei Tools'' Mission (Allowing you to have him craft it), 50 Wolf Fur, 1000 Ryo, and a Sakkat.', 'Headwear', 'Uncommon', null, null, null, 'Benkei''s House — NPC: Benkei', null),
  ('Straw Cape', 'roupa', 'A warm Cape made of animal fur and straw. looks shadily put together, like it was made by a kid... probably named Ali Ali. This cape is obtainable by doing the B-ranked mission Cape of Straw in the Land of Iron arc, available to Ninja Level 53+.', 'Cape', null, 53, null, null, 'NPC: Ali Ali', null),
  ('Uzu Jacket', 'roupa', 'A familiar looking orange jacket with fluffy collars. This piece of clothing is not popular with the ladies one bit!. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7,10 if Gold Member)', 'Cash Shop', null),
  ('Uzushi Jacket', 'roupa', 'A new fashionable jacket from far away country. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7,10 if Gold Member)', 'Cash Shop', null),
  ('Uzu Pants', 'roupa', 'A pair of orange work pants. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Pants', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Uzushi Pants', 'roupa', 'Fashionable pants. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Vest slot of your character.', 'Pants', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('Summoning Robe', 'roupa', 'This cosmetic item is a long purple robe. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Teal Sasu Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Torii Jacket', 'roupa', 'A black fur jacket fashioned from dark beaf fur unkown to this region', null, null, null, null, null, null, null),
  ('Stylish Kunai Pants', 'roupa', 'Fashionable pants with kunai-themed design. This outfit can be crafted through Weaving at level 25.', 'Outfit', 'Crafted', 25, null, null, 'Weaving', null),
  ('Village Nurse Outfits', 'roupa', 'A cosmetic outfit available in village-specific nurse designs. These outfits are available for medical ninja who want to show their dedication to healing.', null, null, null, null, null, null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Stylish and Cute Headphones', 'roupa', 'A pair of stylish headphones worn as a cosmetic accessory.', 'Accessory', 'Premium', null, null, '$9.90 ($8.90 if Gold Member)', 'Cash Shop', null),
  ('Top Hat', 'roupa', 'A classic black top hat for a distinguished look. A seasonal cosmetic available during the Christmas event. You can acquire this from the Christmas Shop using event coupons.', 'Hat', 'Event', null, null, null, 'Christmas Shop', null),
  ('Spring Yukata', 'roupa', 'A traditional yukata with a spring theme, featuring floral designs. This cosmetic can be obtained from the Event Prize Shop using event coupons.', 'Outfit', 'Event', null, null, null, 'Event Prize Shop', null),
  ('Takoyaki Hat', 'roupa', 'A fun hat shaped like takoyaki (octopus balls). This cosmetic can be crafted through Weaving at level 8.', 'Hat', 'Crafted', 8, null, null, 'Weaving', null),
  ('Vigilante Bandana Mask', 'roupa', 'A bandana-style mask worn by vigilantes. This cosmetic can be crafted through Weaving once you obtain the recipe from mob drops.', 'Hat', 'Recipe Drop', null, null, null, 'Weaving', null),
  ('Wanderer Shirt', 'roupa', 'A shirt worn by wandering travelers. This outfit can be crafted through Weaving once you obtain the recipe from mob drops.', 'Outfit', 'Recipe Drop', null, null, null, 'Weaving', null),
  ('Tendo Clan Robe', 'roupa', 'A robe worn by members of the Tendo Clan in Sand Village. This is one of the newer Tendo Clan clothing pieces added for higher-level clan members.', 'Outfit', 'Clan', 30, null, null, 'Tendo Clan House', null),
  ('Tendo Clan Jacket', 'roupa', 'A jacket worn by members of the Tendo Clan in Sand Village. This is one of the newer Tendo Clan clothing pieces added for higher-level clan members.', 'Outfit', 'Clan', 30, null, null, 'Tendo Clan House', null),
  ('Tendo Clan Cape', 'roupa', 'A cape worn by members of the Tendo Clan in Sand Village. This is one of the newer Tendo Clan clothing pieces added for higher-level clan members.', 'Outfit', 'Clan', 30, null, null, 'Tendo Clan House', null),
  ('Tendo Clan Hat', 'roupa', 'A hat worn by members of the Tendo Clan in Sand Village. This is one of the newer Tendo Clan clothing pieces added for higher-level clan members.', 'Hat', 'Clan', 30, null, null, 'Tendo Clan House', null),
  ('Stylish Headphones', 'roupa', 'Stylish Headphones and Cute Headphones are accessory items added in Update v5.10.1. They come in multiple color variants and are available from the Cash Shop.', 'Accessory', null, 1, null, null, null, 'Página sem infobox padrão na wiki — dados extraídos do texto livre.'),
  ('Summer Sunglasses', 'roupa', 'Summer Sunglasses are a cosmetic face accessory added in update v5.12.4 (art by Kvaset). They provide no stat bonuses and are worn for appearance.', 'Mask', null, null, null, null, null, null),
  ('Tight White Chunin Shirt', 'roupa', 'Tight White Chunin Shirt is a cosmetic shirt added to the Event Shop in update v5.11.1. It provides no stat bonuses.', 'Vest', 'Event', null, null, null, 'Event Shop', null),
  ('White Adventure Cloak', 'roupa', 'White Adventure Cloak is one of the colour variants of the Adventure Cloak. It provides no stat bonuses and is worn purely for appearance.', 'Cape', null, null, null, null, null, null),
  ('Tenegui Towel Hat', 'roupa', 'The Tenegui Towel Hat is a Common cosmetic hat crafted through the Weaving proficiency. It gives no stat bonuses and is worn purely for appearance. Its in-game description reads:', 'Hat', 'Common', 25, null, null, 'Weaving', null),
  ('Ushi Mask', 'roupa', 'Ushi Mask is a fearsome mask shaped after the Ushi-Oni, still carrying a trace of its savage aura. It was added in the Land of Spirits Update (2026-07-04).', 'Mask', 'Rare', null, null, null, null, null),
  ('Tengu Pants', 'roupa', 'Tengu Pants are a Unique pants cosmetic: sturdy pants said to carry the spirit of a tengu. They are part of the Tengu set alongside the Tengu Armor.', 'Pants', 'Unique', null, null, null, null, null),
  ('Tengu Armor', 'roupa', 'Tengu Armor is a Unique vest cosmetic: a sturdy armor set said to carry the spirit of the tengu. It is part of the Tengu set alongside the Tengu Pants.', 'Vest', 'Unique', null, null, null, null, null),
  ('Sports Hoodie', 'roupa', 'The Sports Hoodie is a cosmetic top added on July 25, 2026 as a world drop, released in three colours at once. Art by lunacysdead.', 'Cosmetic', 'Rare', null, null, null, null, null),
  ('Tan Camo Top', 'roupa', 'Tan Camo Top is a cosmetic shirt obtained from the War Event. Its in-game description reads:', 'Shirt', 'Event', null, null, '100 War Tokens', 'War Event', null),
  ('Tan Barbarian Cloak', 'roupa', 'Tan Barbarian Cloak is the tan colour variant of the Barbarian Cloak, a Legendary cosmetic vest. Its in-game description reads: "A rugged cloak crafted from the finest leathers and thick furs, built to endure the harshest battles and unforgiving wilderness." It occupies the Vest slot, has no level or stat requirement, and gives no stat bonuses.', 'Vest', 'Legendary', null, null, null, null, null),
  ('White Battle High-Collar Shirt', 'roupa', 'The White Battle High-Collar Shirt is a Event class cosmetic worn in the Shirt slot. Its in-game description reads:', 'Shirt', 'Event', null, null, null, null, null),
  ('Tendo Beserker Pants', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Pants', 'Unique', 30, null, null, null, null),
  ('Tan Adventure Cloak', 'roupa', 'The Tan Adventure Cloak is a Unique class cosmetic worn in the Vest slot. Its in-game description reads:', 'Vest', 'Unique', null, null, null, null, null),
  ('Tiki Mask', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Mask', 'Event', null, null, null, null, null),
  ('Torii Pants', 'roupa', 'The Torii Pants is a Legendary class cosmetic worn in the Pants slot. Its in-game description reads:', 'Pants', 'Legendary', null, null, null, null, null),
  ('Tengai Hat', 'roupa', 'The Tengai Hat is a Rare cosmetic hat. Its in-game description reads:', 'Hat', 'Rare', null, null, null, null, null),
  ('Spotted Arm Sleeves', 'roupa', 'Spotted Arm Sleeves is a Rare class cosmetic worn in the Accessory slot. Its in-game description reads:', 'Accessory', 'Rare', null, null, null, null, null),
  ('Yondaime Cloak', 'roupa', 'The robe that was worn by a hero of the old Great Ninja Wars. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$9.90 ($8,90 if Gold Member)', 'Cash Shop', null),
  ('White Blindfold', 'roupa', 'A white blindfold covering your eyes. Very Nier.Designed by Fuze. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4,40 if Gold Member)', 'Cash Shop', null),
  ('White Fox Mask', 'roupa', 'A festive cat shaped mask that goes over your nose and mouth. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Vest slot of your character.', 'Mask', 'Premium', null, null, '$9.90 ($8,90 if Gold Member)', 'Cash Shop', null),
  ('White Snake Rope Belt', 'roupa', 'This rope wraps around the waist like a snake - a white snake which has shed it''s skin, working as a belt.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 9,90 or $8.90 if you are a gold member and it goes in the Accessory slot of your character.', 'Accessory', 'Premium', null, null, '$9.90 ($8,90 if Gold Member)', 'Cash Shop', null),
  ('Yellow Flash Shirt', 'roupa', 'This is a cosmetic item is a signature piece of clothing among fans of handsome ninjas. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 7,90 or $7.10 if you are a gold member and it goes in the Shirt slot of your character.', 'Shirt', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('White Hashi Overcoat', 'roupa', 'This is a cosmetic item is a plain white overcoat. Can be worn over any shirt and pants, but made to match other items in the Hashi Set.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Yellow Hashi Overcoat', 'roupa', 'This is a cosmetic item is a plain white overcoat. Can be worn over any shirt and pants, but made to match other items in the Hashi Set.. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is 7,90 or $7.10 if you are a gold member and it goes in the Vest slot of your character.', 'Vest', 'Premium', null, null, '$7.90 ($7.10 if Gold Member)', 'Cash Shop', null),
  ('Yellow Visor', 'roupa', 'A translucent visor to see the ninja world through. It comes in the colors Clear, Orange, Yellow, Green, Teal, Blue, Purple, Pink, and Red. You can acquire this from the Cash Shop which is located on NinOnline.org. The cost of one is $4,90 or $4.40 if you are a gold member and it goes in the Mask slot of your character.', 'Mask', 'Premium', null, null, '$4.90 ($4.40 if Gold Ninja)', 'Cash Shop', null),
  ('White Sakkat', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Hat', 'Event', null, null, null, 'Event Prize Shop', null),
  ('Winter Yukata', 'roupa', 'A traditional yukata with a winter theme, perfect for the cold season. Available during winter holiday events. You can acquire this from the Winter Holiday Shop using event coupons.', 'Outfit', 'Event', null, null, null, 'Winter Holiday Shop', null),
  ('White Formal Shirt', 'roupa', 'A clean, formal white shirt suitable for special occasions. Available during winter holiday events. You can acquire this from the Winter Holiday Shop using event coupons.', 'Outfit', 'Event', null, null, null, 'Winter Holiday Shop', null),
  ('White Formal Pants', 'roupa', 'Elegant white formal pants to match formal attire. Available during winter holiday events. You can acquire this from the Winter Holiday Shop using event coupons.', 'Outfit', 'Event', null, null, null, 'Winter Holiday Shop', null),
  ('White Top Hat', 'roupa', 'A classic top hat in white for a distinguished look. A seasonal cosmetic available during the Christmas event. You can acquire this from the Christmas Shop using event coupons.', 'Hat', 'Event', null, null, null, 'Christmas Shop', null),
  ('Yellow Tenegui Towel Hat', 'roupa', 'A traditional towel hat in yellow, worn as headwear. This cosmetic can be crafted through Weaving at level 14.', 'Hat', 'Crafted', 14, null, null, 'Weaving', null),
  ('White Masked Top', 'roupa', 'A masked top outfit in white. This cosmetic can be obtained as an in-game drop.', 'Outfit', 'Drop', null, null, null, 'In-game Drop', null),
  ('Yagyu Traditional Shirt', 'roupa', 'A traditional shirt in the Yagyu style. This cosmetic can be purchased from the Hosoku Shop.', 'Outfit', 'Common', null, null, null, 'Hosoku Shop', null),
  ('Yagyu Traditional Pants', 'roupa', 'Traditional pants in the Yagyu style. This cosmetic can be purchased from the Hosoku Shop.', 'Outfit', 'Common', null, null, null, 'Hosoku Shop', null),
  ('Yagyu Traditional Dress', 'roupa', 'A traditional dress in the Yagyu style. This cosmetic can be purchased from the Hosoku Shop.', 'Outfit', 'Common', null, null, null, 'Hosoku Shop', null),
  ('Yokai Hat', 'roupa', 'Yokai Hat is a mysterious hat touched by the presence of wandering yokai. It was added in the Land of Spirits Update (2026-07-04).', 'Hat', 'Rare', null, null, null, null, null),
  ('Yokai Robe', 'roupa', 'Yokai Robe is a traditional robe worn by those who walk alongside yokai. It was added in the Land of Spirits Update (2026-07-04).', 'Vest', 'Rare', null, null, null, null, null),
  ('Yokai Inner Kimono', 'roupa', 'Yokai Inner Kimono is a soft inner kimono infused with faint yokai energy. It was added in the Land of Spirits Update (2026-07-04).', 'Shirt', 'Rare', null, null, null, null, null),
  ('White War Mantle', 'roupa', 'White War Mantle is a cosmetic vest obtained from the War Event. Its in-game description reads:', 'Vest', 'Event', null, null, '300 War Tokens', 'War Event', null),
  ('White War Headband', 'roupa', 'White War Headband is a cosmetic headwear item obtained from the War Event. Its in-game description reads:', 'Hat', 'Event', null, null, '150 War Tokens', 'War Event', null),
  ('White Wide Sleeve Top', 'roupa', 'White Wide Sleeve Top is an Uncommon cosmetic vest. Its in-game description reads:', 'Vest', 'Uncommon', null, null, null, null, null),
  ('White Fur Cap', 'roupa', 'The White Fur Cap is a Rare class cosmetic worn in the Hat slot. Its in-game description reads:', 'Hat', 'Rare', null, null, null, null, null),
  ('White Wanderer Shirt', 'roupa', 'The White Wanderer Shirt is a Rare class cosmetic worn in the Shirt slot. Its in-game description reads:', 'Shirt', 'Rare', null, null, null, null, null),
  ('White Formal Suit', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Shirt', 'Event', 36, null, null, null, null),
  ('White Twinfall Scarf', 'roupa', 'The White Twinfall Scarf is a Rare class cosmetic worn in the Mask slot. Its in-game description reads:', 'Mask', 'Rare', null, null, null, null, null),
  ('White Chunin Battle Suit', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Shirt', 'Uncommon', 30, null, null, null, null),
  ('Yamato Protector', 'roupa', 'This is role-gated — the requirement is who you are, not what level you are.', 'Hat', 'Uncommon', null, null, null, null, null),
  ('Winter Justice Cape', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Vest', 'Event', null, null, null, null, null),
  ('White Hooded Cloak', 'roupa', 'White Hooded Cloak is an Event class cosmetic vest requiring Lv. 23. Its in-game description reads:', 'Vest', 'Event', 23, null, null, null, null),
  ('Winter Hanzo Mask', 'roupa', 'An event-exclusive item. See that page for what is obtainable when.', 'Hat', 'Event', null, null, null, null, null),
  ('Witches Hat', 'roupa', 'Witches Hat is a set of 2 cosmetic hat variants sold at the Halloween Shop in Haunted Hollow. The in-game description reads: "Nobody really knows what a witch is, but if there were witches around, this is probably what they would wear." All variants are marked Exclusive to Halloween Events and were added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow', null),
  ('Wizard Hat', 'roupa', 'Wizard Hat is a set of 3 cosmetic hat variants sold at the Halloween Shop in Haunted Hollow. The in-game description reads: "Nobody really knows what a wizard is, but if there were wizards around, this is probably what they would wear." All variants are marked Exclusive to Halloween Events and were added in Update v6.', 'Hat', null, null, null, null, 'Halloween Shop, Haunted Hollow', null)
on conflict (lower(name)) do update set
  type = 'roupa',
  description = coalesce(excluded.description, items.description),
  clothing_slot = excluded.clothing_slot,
  clothing_rarity = excluded.clothing_rarity,
  clothing_level_required = excluded.clothing_level_required,
  clothing_price_ryo = excluded.clothing_price_ryo,
  clothing_price_text = excluded.clothing_price_text,
  clothing_source = excluded.clothing_source,
  clothing_notes = excluded.clothing_notes
-- só reclassifica/atualiza um item já existente se ele ainda for o
-- placeholder genérico criado pela migração de mobs (type = 'item_mob',
-- sem descrição) -- nunca sobrescreve um item de outro tipo real (arma,
-- anel, consumível) que por acaso tenha o mesmo nome, nem um 'roupa' que
-- o admin já tenha editado manualmente com uma descrição própria.
where items.type = 'roupa'
   or (items.type = 'item_mob' and items.description is null);

-- ---------------------------------------------------------------
-- updated_at automático + RLS
-- ---------------------------------------------------------------
drop trigger if exists proficiencies_set_updated_at on proficiencies;
create trigger proficiencies_set_updated_at
  before update on proficiencies
  for each row execute function set_updated_at();

drop trigger if exists proficiency_recipes_set_updated_at on proficiency_recipes;
create trigger proficiency_recipes_set_updated_at
  before update on proficiency_recipes
  for each row execute function set_updated_at();

alter table proficiencies enable row level security;
alter table proficiency_recipes enable row level security;
alter table proficiency_recipe_materials enable row level security;

drop policy if exists proficiencies_public_read on proficiencies;
create policy proficiencies_public_read on proficiencies for select using (true);

drop policy if exists proficiencies_auth_write on proficiencies;
create policy proficiencies_auth_write on proficiencies for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists proficiency_recipes_public_read on proficiency_recipes;
create policy proficiency_recipes_public_read on proficiency_recipes for select using (true);

drop policy if exists proficiency_recipes_auth_write on proficiency_recipes;
create policy proficiency_recipes_auth_write on proficiency_recipes for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists proficiency_recipe_materials_public_read on proficiency_recipe_materials;
create policy proficiency_recipe_materials_public_read on proficiency_recipe_materials for select using (true);

drop policy if exists proficiency_recipe_materials_auth_write on proficiency_recipe_materials;
create policy proficiency_recipe_materials_auth_write on proficiency_recipe_materials for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- ---------------------------------------------------------------
-- Seed: as 10 proficiências
-- ---------------------------------------------------------------
insert into proficiencies (slug, name, category, description, level_cap) values
  ('mineracao', 'Mineração', 'coleta', 'Extração de minério de nós de minério espalhados pelo mundo, usando uma picareta comprada no Ferreiro da vila. Cada nó minerado dá 2 XP. Minérios são refinados em lingotes através da Forjaria. A página "Mining" da wiki hoje só redireciona pra um resumo genérico (Gathering Proficiencies) — sem dados de nós/rotas específicos documentados ainda.', 500),
  ('corte_madeira', 'Corte de Madeira', 'coleta', 'Corte de árvores (variantes Basic, Thin e Huge) pra coletar toras e subir o nível da profissão. O tipo de tora depende do território: Vibrant na Folha, Dull perto da Areia e fronteiras Rogue, Dark na Névoa. A wiki documenta uma tabela de nível 1 a 30 com dano por golpe, XP e rendimento de toras por árvore.', 500),
  ('pesca', 'Pesca', 'coleta', 'Pesca de peixes e outros achados em qualquer tile de água de uns 2x2 ou maior, usando uma vara. Varas vão de uma Cheap Rod de 2.000 Ryo até uma Aerongel Gold Rod de 500.000 Ryo. Boa parte das receitas de Culinária depende de peixes raros pescados com tiers avançados de isca (Baiting Basics).', 500),
  ('forrageamento', 'Forrageamento', 'coleta', 'Coleta de frutinhas (berries), ervas, fibra e arroz de nós espalhados pelo mundo. Ainda sem página própria na wiki, mas é a que mais alimenta a Culinária — só o Arroz entra 5 unidades por Rice Ball.', 500),
  ('forjaria', 'Forjaria', 'crafting', 'Transforma minérios em lingotes, e lingotes em itens de metal. Ainda sem página própria detalhada na wiki — o link "Forging" hoje só redireciona pra um resumo genérico (Crafting Proficiencies), sem lista de receitas.', 500),
  ('tecelagem', 'Tecelagem', 'crafting', 'Transforma fibra, linha e couro em roupas, usando uma Bancada de Trabalho (Workbench). Foca em itens vestíveis e materiais de crafting como tiras de couro e folhas de tecido. Algumas receitas só aparecem depois de obtidas como drop de mob específico.', 500),
  ('carpintaria', 'Carpintaria', 'crafting', 'Transforma toras em tábuas e móveis, até uma Barraca de Mercado do Jogador (Player Market Stall) — o item craftado de maior valor já registrado na wiki (22.500 Ryo). Ainda sem página própria detalhada.', 500),
  ('culinaria', 'Culinária', 'crafting', 'Transforma frutinhas, arroz, ovos e peixe em comida que cura, descansa ou dá bônus de atributo por 30 minutos. As receitas mais fortes são vendidas pelo Chef em Takumi Village e exigem Culinária 18+. Substituiu o antigo sistema de Charms (Horóscopos e Amuletos), desativado na v5.13.2.', 500),
  ('transmutacao', 'Transmutação', 'crafting', 'Transforma ervas e óleos em suprimentos médicos, como Bandagens e Óleo de Sapo (Toad Oil). Ainda sem página própria detalhada na wiki.', 500),
  ('fuinjutsu', 'Fuinjutsu', 'crafting', 'Transforma Pergaminhos em Branco (Blank Scroll) em pergaminhos de jutsu selados e, no topo da progressão, Contratos de Invocação. Ainda sem página própria detalhada na wiki.', 500)
on conflict (slug) do update set
  name = excluded.name,
  category = excluded.category,
  description = excluded.description,
  level_cap = excluded.level_cap;

-- ---------------------------------------------------------------
-- Seed: itens novos (produtos e ingredientes de receita)
-- ---------------------------------------------------------------
insert into items (name, type) values
  ('Arapaima', 'consumivel'),
  ('Black High Heel Boots', 'consumivel'),
  ('Black Tenegui Towel Hat', 'consumivel'),
  ('Blight Leechskin Scarf', 'consumivel'),
  ('Blobfish', 'consumivel'),
  ('Blue Berries', 'consumivel'),
  ('Blue Berry Cake', 'consumivel'),
  ('Blue Catfish', 'consumivel'),
  ('Blue Shark', 'consumivel'),
  ('Blue Tenegui Towel Hat', 'consumivel'),
  ('Bottled Honey', 'consumivel'),
  ('Bread', 'consumivel'),
  ('Brown Catfish', 'consumivel'),
  ('Carrot', 'consumivel'),
  ('Crimson Leechskin Scarf', 'consumivel'),
  ('Crispy Fish', 'consumivel'),
  ('Dark Barbarian Cloak', 'consumivel'),
  ('Deep Sea Hotdog', 'consumivel'),
  ('Dwarf Gourami', 'consumivel'),
  ('Egg', 'consumivel'),
  ('Egg Sushi', 'consumivel'),
  ('Electric Fish', 'consumivel'),
  ('Fabric Sheets', 'consumivel'),
  ('Firefish', 'consumivel'),
  ('Fish Soup', 'consumivel'),
  ('Fish Sushi', 'consumivel'),
  ('Flour', 'consumivel'),
  ('Fried Egg', 'consumivel'),
  ('Green Tenegui Towel Hat', 'consumivel'),
  ('Grey Barbarian Cloak', 'consumivel'),
  ('Grey Shark', 'consumivel'),
  ('Grilled Arapaima', 'consumivel'),
  ('Honey & Herb Fish', 'consumivel'),
  ('Jellyfish', 'consumivel'),
  ('Jellyfish Takoyaki', 'consumivel'),
  ('Leaf Style Omelette', 'consumivel'),
  ('Leather Strips', 'consumivel'),
  ('Maki Sushi', 'consumivel'),
  ('Maki Sushi Hat', 'consumivel'),
  ('Milk', 'consumivel'),
  ('Mist Style Omelette', 'consumivel'),
  ('Penguin Wings', 'consumivel'),
  ('Pink Tenegui Towel Hat', 'consumivel'),
  ('Puppet Mask', 'consumivel'),
  ('Purple Tenegui Towel Hat', 'consumivel'),
  ('Reaper Death Sauce', 'consumivel'),
  ('Red Anchovy', 'consumivel'),
  ('Red Berries', 'consumivel'),
  ('Red Berry Cake', 'consumivel'),
  ('Red High Heel Boots', 'consumivel'),
  ('Red Tenegui Towel Hat', 'consumivel'),
  ('Rice', 'consumivel'),
  ('Rice Ball', 'consumivel'),
  ('Sand Style Omelette', 'consumivel'),
  ('Seaweed', 'consumivel'),
  ('Shark Curry', 'consumivel'),
  ('Sharks Fin', 'consumivel'),
  ('Slug Venom', 'consumivel'),
  ('Slugskin Scarf', 'consumivel'),
  ('Spicy Fried Shark', 'consumivel'),
  ('Spicy Fried Wings', 'consumivel'),
  ('Spider Eggs', 'consumivel'),
  ('Stylish Kunai Pants', 'consumivel'),
  ('Tadpole Egg', 'consumivel'),
  ('Takoyaki Hat', 'consumivel'),
  ('Tan Barbarian Cloak', 'consumivel'),
  ('Temaki', 'consumivel'),
  ('Tentacle', 'consumivel'),
  ('Tunneler Tongue', 'consumivel'),
  ('Vegetarian Instant Ramen', 'consumivel'),
  ('Vigilante Bandana Mask', 'consumivel'),
  ('Wanderer Shirt', 'consumivel'),
  ('Wool String', 'consumivel'),
  ('Yellow Tenegui Towel Hat', 'consumivel')
on conflict (lower(name)) do nothing;

-- ---------------------------------------------------------------
-- Seed: receitas (Tecelagem + Culinária)
-- ---------------------------------------------------------------
insert into proficiency_recipes (proficiency_id, name, output_item_id, level_required, success_rate_base, craft_time_seconds, requires_workbench, effect_description, notes) values
  ((select id from proficiencies where slug = 'tecelagem'), 'Leather Strips', (select id from items where lower(name) = lower('Leather Strips')), 5, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Wool String', (select id from items where lower(name) = lower('Wool String')), 8, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Takoyaki Hat', (select id from items where lower(name) = lower('Takoyaki Hat')), 8, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Blue Tenegui Towel Hat', (select id from items where lower(name) = lower('Blue Tenegui Towel Hat')), 9, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Fabric Sheets', (select id from items where lower(name) = lower('Fabric Sheets')), 10, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Green Tenegui Towel Hat', (select id from items where lower(name) = lower('Green Tenegui Towel Hat')), 10, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Blight Leechskin Scarf', (select id from items where lower(name) = lower('Blight Leechskin Scarf')), 11, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Pink Tenegui Towel Hat', (select id from items where lower(name) = lower('Pink Tenegui Towel Hat')), 11, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Crimson Leechskin Scarf', (select id from items where lower(name) = lower('Crimson Leechskin Scarf')), 12, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Purple Tenegui Towel Hat', (select id from items where lower(name) = lower('Purple Tenegui Towel Hat')), 12, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Slugskin Scarf', (select id from items where lower(name) = lower('Slugskin Scarf')), 13, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Red Tenegui Towel Hat', (select id from items where lower(name) = lower('Red Tenegui Towel Hat')), 13, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Yellow Tenegui Towel Hat', (select id from items where lower(name) = lower('Yellow Tenegui Towel Hat')), 14, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Black Tenegui Towel Hat', (select id from items where lower(name) = lower('Black Tenegui Towel Hat')), 15, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Red High Heel Boots', (select id from items where lower(name) = lower('Red High Heel Boots')), 18, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Black High Heel Boots', (select id from items where lower(name) = lower('Black High Heel Boots')), 19, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Stylish Kunai Pants', (select id from items where lower(name) = lower('Stylish Kunai Pants')), 25, null, null, false, null, null),
  ((select id from proficiencies where slug = 'tecelagem'), 'Vigilante Bandana Mask', (select id from items where lower(name) = lower('Vigilante Bandana Mask')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Puppet Mask', (select id from items where lower(name) = lower('Puppet Mask')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Wanderer Shirt', (select id from items where lower(name) = lower('Wanderer Shirt')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Maki Sushi Hat', (select id from items where lower(name) = lower('Maki Sushi Hat')), null, null, null, false, null, 'Receita obtida via drop de mob (fonte não registrada na wiki).'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Dark Barbarian Cloak', (select id from items where lower(name) = lower('Dark Barbarian Cloak')), null, null, null, false, null, 'Receita obtida via drop do mob Black Bear.'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Grey Barbarian Cloak', (select id from items where lower(name) = lower('Grey Barbarian Cloak')), null, null, null, false, null, 'Receita obtida via drop do mob Alpha Leopard.'),
  ((select id from proficiencies where slug = 'tecelagem'), 'Tan Barbarian Cloak', (select id from items where lower(name) = lower('Tan Barbarian Cloak')), null, null, null, false, null, 'Receita obtida via drop do mob Spirit Fox.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Rice Ball', (select id from items where lower(name) = lower('Rice Ball')), null, 90.0, 2, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Base de sucesso confirmada em 90% (a única confirmada na wiki, no skill 0).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Fried Egg', (select id from items where lower(name) = lower('Fried Egg')), null, 50.0, 2, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Base aproximada (~50%), lida a 1% de skill (91% e 50,5% respectivamente), não confirmada no skill 0.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Maki Sushi', (select id from items where lower(name) = lower('Maki Sushi')), null, null, null, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Taxa de sucesso e tempo de craft não registrados.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Egg Sushi', (select id from items where lower(name) = lower('Egg Sushi')), null, null, null, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Taxa de sucesso e tempo de craft não registrados.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Fish Sushi', (select id from items where lower(name) = lower('Fish Sushi')), null, null, null, false, 'Cura 100 HP e deixa o personagem descansado (leva 4s pra comer).', 'Taxa de sucesso e tempo de craft não registrados.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Leaf Style Omelette', (select id from items where lower(name) = lower('Leaf Style Omelette')), null, null, null, false, '+1 em todos os atributos por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Mist Style Omelette', (select id from items where lower(name) = lower('Mist Style Omelette')), null, null, null, false, '+1 em todos os atributos por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Sand Style Omelette', (select id from items where lower(name) = lower('Sand Style Omelette')), null, null, null, false, '+1 em todos os atributos por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Blue Berry Cake', (select id from items where lower(name) = lower('Blue Berry Cake')), null, null, null, true, '+5 Intellect por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Red Berry Cake', (select id from items where lower(name) = lower('Red Berry Cake')), null, null, null, true, '+5 Strength por 30 minutos.', null),
  ((select id from proficiencies where slug = 'culinaria'), 'Grilled Arapaima', (select id from items where lower(name) = lower('Grilled Arapaima')), null, null, null, false, '+5 Fortitude por 30 minutos.', 'Arapaima é uma pesca Rare (isca tier III).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Crispy Fish', (select id from items where lower(name) = lower('Crispy Fish')), null, null, null, false, '+5 Agility por 30 minutos.', 'Brown Catfish é uma pesca Rare (isca tier II).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Temaki', (select id from items where lower(name) = lower('Temaki')), null, null, null, false, '+5 Chakra por 30 minutos.', 'Blue Catfish é uma pesca Rare (isca tier II).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Honey & Herb Fish', (select id from items where lower(name) = lower('Honey & Herb Fish')), null, null, null, false, '+3 em todos os atributos por 30 minutos.', 'Único prato que dá +3 em todos os atributos. Electric Fish é uma pesca Unique (isca tier III).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Spicy Fried Wings', (select id from items where lower(name) = lower('Spicy Fried Wings')), 18, null, null, false, '+10 Agility, +4 Fortitude por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Fish Soup', (select id from items where lower(name) = lower('Fish Soup')), 18, null, null, false, '+10 Intellect, +4 Fortitude por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Spicy Fried Shark', (select id from items where lower(name) = lower('Spicy Fried Shark')), 18, null, null, false, '+10 Strength, +4 Chakra por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+ (nome do jogo tem erro de grafia: "Strenght").'),
  ((select id from proficiencies where slug = 'culinaria'), 'Shark Curry', (select id from items where lower(name) = lower('Shark Curry')), 18, null, null, false, '+10 Strength, +4 Fortitude por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+ (nome do jogo tem erro de grafia: "Strenght").'),
  ((select id from proficiencies where slug = 'culinaria'), 'Deep Sea Hotdog', (select id from items where lower(name) = lower('Deep Sea Hotdog')), 18, null, null, false, '+10 Agility, +4 Chakra por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+.'),
  ((select id from proficiencies where slug = 'culinaria'), 'Jellyfish Takoyaki', (select id from items where lower(name) = lower('Jellyfish Takoyaki')), 18, null, null, false, '+10 Intellect, +4 Chakra por 30 minutos.', 'Vendida pelo Chef em Takumi Village, exige Culinária 18+. Jellyfish é a pesca de tier mais alto registrada (Baiting Basics IV).'),
  ((select id from proficiencies where slug = 'culinaria'), 'Reaper Death Sauce', (select id from items where lower(name) = lower('Reaper Death Sauce')), null, null, null, false, null, 'Único ingrediente usado noutras receitas (Spicy Fried Wings, Spicy Fried Shark) cuja própria receita não é vendida pelo Chef — ela dropa do mob Kiemon. Firefish é uma pesca Rare (isca tier III).')
on conflict (proficiency_id, name) do update set
  output_item_id = excluded.output_item_id,
  level_required = excluded.level_required,
  success_rate_base = excluded.success_rate_base,
  craft_time_seconds = excluded.craft_time_seconds,
  requires_workbench = excluded.requires_workbench,
  effect_description = excluded.effect_description,
  notes = excluded.notes;

-- ---------------------------------------------------------------
-- Seed: ingredientes das receitas de Culinária
-- ---------------------------------------------------------------
insert into proficiency_recipe_materials (recipe_id, item_id, quantity) values
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Rice Ball'), (select id from items where lower(name) = lower('Rice')), 5),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fried Egg'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Maki Sushi'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Maki Sushi'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Egg Sushi'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Egg Sushi'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Egg Sushi'), (select id from items where lower(name) = lower('Tadpole Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Sushi'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Sushi'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Sushi'), (select id from items where lower(name) = lower('Dwarf Gourami')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Leaf Style Omelette'), (select id from items where lower(name) = lower('Egg')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Leaf Style Omelette'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Leaf Style Omelette'), (select id from items where lower(name) = lower('Spider Eggs')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Mist Style Omelette'), (select id from items where lower(name) = lower('Egg')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Mist Style Omelette'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Mist Style Omelette'), (select id from items where lower(name) = lower('Sharks Fin')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Sand Style Omelette'), (select id from items where lower(name) = lower('Egg')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Sand Style Omelette'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Sand Style Omelette'), (select id from items where lower(name) = lower('Tunneler Tongue')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Blue Berries')), 5),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Blue Berry Cake'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Milk')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Red Berry Cake'), (select id from items where lower(name) = lower('Red Berries')), 5),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Grilled Arapaima'), (select id from items where lower(name) = lower('Arapaima')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Grilled Arapaima'), (select id from items where lower(name) = lower('Bottled Honey')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Crispy Fish'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Crispy Fish'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Crispy Fish'), (select id from items where lower(name) = lower('Brown Catfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Temaki'), (select id from items where lower(name) = lower('Rice Ball')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Temaki'), (select id from items where lower(name) = lower('Seaweed')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Temaki'), (select id from items where lower(name) = lower('Blue Catfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Honey & Herb Fish'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Honey & Herb Fish'), (select id from items where lower(name) = lower('Bottled Honey')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Honey & Herb Fish'), (select id from items where lower(name) = lower('Electric Fish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Wings'), (select id from items where lower(name) = lower('Reaper Death Sauce')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Wings'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Wings'), (select id from items where lower(name) = lower('Penguin Wings')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Vegetarian Instant Ramen')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Carrot')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Blobfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Fish Soup'), (select id from items where lower(name) = lower('Red Anchovy')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Shark'), (select id from items where lower(name) = lower('Grey Shark')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Shark'), (select id from items where lower(name) = lower('Reaper Death Sauce')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Spicy Fried Shark'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Shark Curry'), (select id from items where lower(name) = lower('Rice Ball')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Shark Curry'), (select id from items where lower(name) = lower('Carrot')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Shark Curry'), (select id from items where lower(name) = lower('Blue Shark')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Deep Sea Hotdog'), (select id from items where lower(name) = lower('Bread')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Deep Sea Hotdog'), (select id from items where lower(name) = lower('Tentacle')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Deep Sea Hotdog'), (select id from items where lower(name) = lower('Red Anchovy')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Jellyfish Takoyaki'), (select id from items where lower(name) = lower('Flour')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Jellyfish Takoyaki'), (select id from items where lower(name) = lower('Egg')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Jellyfish Takoyaki'), (select id from items where lower(name) = lower('Jellyfish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Reaper Death Sauce'), (select id from items where lower(name) = lower('Firefish')), 1),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Reaper Death Sauce'), (select id from items where lower(name) = lower('Red Berries')), 2),
  ((select rec.id from proficiency_recipes rec join proficiencies pr on pr.id = rec.proficiency_id where pr.slug = 'culinaria' and rec.name = 'Reaper Death Sauce'), (select id from items where lower(name) = lower('Slug Venom')), 1)
on conflict (recipe_id, item_id) do update set
  quantity = excluded.quantity;


-- Migração 016: cadastro das Montarias (Mounts) do jogo, extraídas de
-- https://ninonline.fandom.com/wiki/Category:Mounts (14 páginas na
-- categoria).
--
-- 13 das 14 páginas são montarias de fato e viram uma linha na nova
-- tabela `mounts`. A 14ª, "Taming Flute" (o item usado pra domesticar
-- as montarias tameáveis), não é uma montaria em si -- foi cadastrada
-- na tabela `items` como `type = 'consumivel'`.
--
-- Colunas de `mounts`:
--   - is_starter / village_id / obtain_level: as 3 montarias iniciais
--     (Boar = Névoa nível 15, Tiger = Folha nível 20, Wolf = Areia
--     nível 20), obtidas via missões de Domador de Feras da vila.
--   - flying: hoje só a Hawk Mount (personagem renderiza acima da
--     franja do cenário quando montado).
--   - tame_target: a criatura selvagem domesticável com a Taming
--     Flute pra obter aquela montaria (null quando não é obtida por
--     domesticação -- ex: Tsuchigumo, que vem de drop de boss, e
--     Lantern, que é comprada).
--   - source: resumo em texto livre de como obter.
--   - notes: detalhes extras (bônus de vantagem das iniciais, crédito
--     de arte, ou aviso de que a wiki ainda não documentou o método).
--
-- Hornet Mount e Clay Bird Black Mount: a própria wiki marca o método
-- de obtenção como "ainda sendo documentado" -- ficou registrado
-- assim em `notes`, sem inventar dado.

create table if not exists mounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  image_url text,

  -- Montaria inicial de vila (Beast Tamer missions).
  is_starter boolean not null default false,
  village_id text references villages(id) on delete set null,
  obtain_level integer,

  flying boolean not null default false,
  tame_target text,
  source text,
  notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists mounts_village_id_idx on mounts (village_id);
create unique index if not exists mounts_name_unique_idx on mounts (lower(name));

insert into mounts (name, description, is_starter, village_id, obtain_level, flying, tame_target, source, notes) values
  ('Boar Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', true, 'neblina', 15, false, 'Boar', 'Starter mount of the Mist Village, obtained through the village''s Beast Tamer missions at Level 15. Wild Boars can also be tamed with a Taming Flute.', 'Notably faster than the other starter mounts, lasts 20 seconds longer per summon, and has a 10 second shorter cooldown.'),
  ('Tiger Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', true, 'folha', 20, false, 'Tiger', 'Starter mount of the Leaf Village, obtained through the village''s Beast Tamer missions at Level 20. Wild Tigers can also be tamed with a Taming Flute.', null),
  ('Wolf Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', true, 'areia', 20, false, 'Wolf', 'Starter mount of the Sand Village, obtained through the village''s Beast Tamer missions at Level 20. Wild Wolves can also be tamed with a Taming Flute.', null),
  ('White Tiger Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, 'White Tiger', 'Tamed from the White Tiger with a Taming Flute. Non-starter mounts are harder to tame and considered rare novelty items.', null),
  ('Snow Leopard Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, 'Alpha Snow Leopard', 'Tamed from the Alpha Snow Leopard of the Land of Iron with a Taming Flute. Non-starter mounts are harder to tame and considered rare novelty items.', null),
  ('Leno Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, 'Leno', 'Tamed from Leno, found near Takumi Village, with a Taming Flute. Non-starter mounts are harder to tame and considered rare novelty items.', null),
  ('Alpha Wolf Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, 'Alpha Wolf', 'Tamed from the Alpha Wolf (Bandit Arc) with a Taming Flute. Non-starter mounts are harder to tame and considered rare novelty items.', null),
  ('Scarab Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, 'Huge Scarab', 'Tamed from the Huge Scarab of the desert regions with a Taming Flute. Non-starter mounts are harder to tame and considered rare novelty items.', null),
  ('Hawk Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, true, 'Hawk', 'Tamed from the Hawk (Land of Toads Arc) with a Taming Flute.', 'Flying mount: characters riding it render above the terrain fringe.'),
  ('Hornet Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, null, null, 'Obtain method not yet documented on the wiki as of the last data pull.'),
  ('Clay Bird Black Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, null, null, 'Obtain method not yet documented on the wiki as of the last data pull.'),
  ('Tsuchigumo Mount', 'A rideable mount. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, null, 'Granted by the Tsuchigumo Mount Whistle, which drops from Kikkumaru, the Level 74 boss yokai of the Land of Spirits. Added in the 2026-07-11 patch alongside the tamable Giant Ant and Giant Fire Ant.', null),
  ('Lantern Mount', 'A rideable mount: a red paper lantern the rider sits on. Like all mounts it negates stamina usage while riding, requires a rested state to summon, and cannot be used to cast jutsu while mounted.', false, null, null, false, null, 'Summoned with the Lantern Whistle, sold in the Yokai Prestige Shop in the Land of Spirits (unlocks after completing the arc). The whistle costs 500 Yokai Coin.', 'Added on 13 September 2026 by Kenock alongside the Yokai Lantern Stand, Yokai Bed and Yokai Chest Recipe. Mount art by Azuki.')
on conflict (lower(name)) do update set
  description = excluded.description,
  is_starter = excluded.is_starter,
  village_id = excluded.village_id,
  obtain_level = excluded.obtain_level,
  flying = excluded.flying,
  tame_target = excluded.tame_target,
  source = excluded.source,
  notes = excluded.notes;

-- ---------------------------------------------------------------
-- updated_at automático + RLS (tabela nova)
-- ---------------------------------------------------------------
drop trigger if exists mounts_set_updated_at on mounts;
create trigger mounts_set_updated_at
  before update on mounts
  for each row execute function set_updated_at();

alter table mounts enable row level security;

drop policy if exists mounts_public_read on mounts;
create policy mounts_public_read on mounts for select using (true);

drop policy if exists mounts_auth_write on mounts;
create policy mounts_auth_write on mounts for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- ---------------------------------------------------------------
-- Taming Flute: registrado em `items` (não é uma montaria, é o item
-- usado pra domesticar as montarias tameáveis acima).
-- ---------------------------------------------------------------
insert into items (name, type, description) values
  ('Taming Flute', 'consumivel', 'The item used to tame wild creatures as mounts. Use it on the sub-boss version of a creature (for example the Enraged Wolf) — the lower the creature''s HP when you attempt the tame, the higher the success chance. Non-starter mounts are harder to tame and considered rare novelty items. Where the flute itself is obtained is still being documented on the wiki.')
on conflict (lower(name)) do update set
  type = 'consumivel',
  description = coalesce(items.description, excluded.description)
where items.type = 'item_mob' and items.description is null;

-- Migração 017: cadastro das missões que ficaram de fora da migração 010
-- (que cobriu só as ~63 Missões Diárias) -- as questlines de storyline e
-- missões de NPC específico, extraídas de
-- https://ninonline.fandom.com/wiki/Category:Missions (141 páginas na
-- categoria; 72 delas ainda não estavam cadastradas).
--
-- 74 linhas novas, a partir de 70 páginas (72 páginas − 2 fora de
-- escopo, ver abaixo):
--
--   - "Sea Mini Questlines" ficou de fora: a própria página se marca
--     como depreciada em 15/09/2026 (update v5.13.6.9) -- as missões
--     "Rite of Passage" e "Riddle of the Blood" foram removidas do
--     jogo e substituídas por uma questline nova (nível 45, Denkai/
--     Asoki) que a wiki ainda não documenta sob título próprio.
--   - "Yuu Mini Questline" ficou de fora: não é uma missão em si, é um
--     walkthrough passo-a-passo que complementa "Hidden Tomb" (a
--     missão de verdade, com recompensa e localização dos selos, já
--     está cadastrada abaixo).
--   - 3 páginas "hub" do Land of Toads (a introdução de Hitsutomo, a
--     cadeia de coleta de Hoshitomo e a cadeia de caça de Momotomo)
--     documentam mais de uma missão na mesma página -- cada uma virou
--     sua própria linha (Land Of Toads I/II; Obtain Talons/Feathers/
--     Raccoon Tails; Natural Enemies I/II), 7 linhas ao todo.
--
-- Rank: 8 missões de storyline (Takumi arc, selos de vila, Kinsen
-- Mobsters) usam "Main" na wiki, fora da escala S/A/B/C/D do enum
-- `mission_rank`. Entraram como rank 'S' com uma nota explícita no
-- `description` dizendo que o rank real da wiki é "Main". O mesmo vale
-- pra qualquer outro rank/nível/recompensa que a wiki não documenta
-- ("Information needed") ou documenta num formato fora do padrão --
-- vira nota no `description` em vez de um chute.
--
-- Vila: as 3 missões de "achar os selos da vila" (Cleanse The Temple,
-- Hidden in the Desert, Darker Places) entraram com `village_id` da
-- vila correspondente (Névoa/Areia/Folha) -- são claramente exclusivas
-- daquela vila. As demais ficaram com `village_id` null.
--
-- Arco: `arco_id` ficou null pra todas -- os 4 arcos cadastrados hoje
-- (20/30/50/60) são as instâncias do mapa principal, e essas missões
-- de storyline acontecem em regiões nomeadas à parte (Land of Iron,
-- Land of Spirits, Land of Toads, Kinsen Quarters...) sem uma
-- correspondência 1:1 documentada com esses IDs; mapear isso fica pra
-- quando o mapa dessas regiões existir no site.
--
-- Diária: só "Hornet Infestation" entrou como `mission_type = 'diaria'`
-- -- é a única desse lote que a própria wiki chama de "repeatable daily
-- mission". As outras 73 entraram como 'global' (nenhuma é exclusiva
-- de arco no sentido do enum, e nenhuma é evento temporário).
--
-- Objetivos: `objectives` (o campo estruturado {item, quantidade} que
-- a migração 010 usa pra "matar N de X") ficou vazio pra todas as
-- linhas deste lote -- a maioria é narrativa (fale com X, escolte,
-- explore, resolva um enigma) mesmo quando tem contagem de kill
-- embutida; o texto completo dos objetivos (quando a wiki documenta)
-- foi pro `description`, no mesmo espírito da migração 010.
--
-- XP/Ryo: extraídos só quando a wiki dá um número limpo (ex: "220,600
-- EXP + 50 Ryo"). Recompensa em item, título, cupom, ou texto livre
-- ("New Title + Furniture", "5 Blood Pills IV") vira nota no
-- `description` em vez de um valor inventado; onde a wiki não
-- documenta a recompensa ("Information needed"), XP/Ryo ficam 0 com a
-- mesma nota.

insert into missions (name, description, mission_type, rank, village_id, xp, ryo, level_min, level_max) values
  ('Benkei''s Tools', 'Benkei, an old man from the Land of Iron who now resides in Takumi Village needs your help. He was chased by thugs near Takumi, quick thinkingly he threw his precious tools into a river hoping to retrieve them later, but they went missing.
Note: Completing this mission allows you to access his crafting abilities to create Veiled Sakkat.
You can find them in the northern River Bank of Takumi River in front of a rock wall with a mysterious stone in it.', 'global', 'D', null, 2500, 0, null, null),
  ('Cape of Straw', 'Upon meeting Ali Ali in the Land of iron, you will receive the difficult task of gathering Leopard tails for reasons unknown. Your hard work will not be in vain, for upon completion of this task will be given a Straw Cape. Leopard tails are obtainable from Leopards that inhabit the Iron Forest.

Recompensa adicional (wiki): "Straw Cape".', 'global', 'B', null, 151500, 0, 53, null),
  ('Blocked Entry', 'Blocked Entry is a mission available to take from level 36+
To get this mission you need to go to Bandit Bridge and find NPC called Ku.
Ku wants u to kill Koji who hides in Bandit Cave.

Recompensa adicional (wiki): "80 ryo".', 'global', 'C', null, 265200, 80, 36, null),
  ('Baiting Basics I', 'The local fisherman has a simple request: collect one of each common fish. But as you start handing over your catches, you notice a glint in his eye - the fisherman may be a bit shady, and surprisingly picky about the quality. Only the best of each catch will satisfy him, so inspect every fish before you turn it over!', 'global', 'D', null, 0, 0, null, null),
  ('Cleanse The Temple', 'You met Ikayasu outside the Furniture Shop in the Mist Village, he enlisted your help to cleanse the sealed temple, you''re tasked with removing the seals around the village which releases the barrier in the cave north west from the Mist Village.
Level 20

Objetivos (wiki): * Remove 5 seals inside the Mist Village / * Report back to Ikayasu / * Unlock the Ant Tunnel Seal / * Go To Sealed Temple / * Report back to Ikayasu

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', 'neblina', 30900, 0, null, null),
  ('A Lord''s Legacy', 'Objetivos (wiki): * Kill Royal Spirit / * Lay his bones to peace in the Royal Lantern

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', null, 4500, 0, null, null),
  ('Among the Yokai', 'Part of the Land of Spirits Storyline
"Lady Kitsune has asked you to walk among the villagers. Each one carries a piece of what is happening to this land and none of them will say it plainly. Listen carefully."

Objetivos (wiki): * Speak with all eight Yokai Village residents (0/8): Okuri, Yuki, Bunbuku, Bakan, Hito, Nekomata, Ningyo, Rokuro / * Return to Lady Kitsune

Recompensa inclui item(ns) não especificado(s) pela wiki.', 'global', 'B', null, 260400, 0, 60, null),
  ('Binding Ofuda', 'Part of the Land of Spirits Storyline.
"Hito has pointed you toward the Goshinboku Tree, a sacred tree deep in the Land of Spirits sealed off by ofuda. Find it, destroy the seals binding it, and uncover the entrance that''s been hidden behind them."

Objetivos (wiki): * Talk to Hito / * Find the Goshinboku Tree (Spiritcore Crater map: up the bridge, then jump to the waterfall on your right) / * Destroy the scattered binding seals / * Report back to Hito', 'global', 'B', null, 375400, 0, 60, null),
  ('Cleanse the Remnants I', 'Cleanse the Remnants I is an A-Rank mission in the Land of Spirits, given by Rokuro.

Objetivos (wiki): * Kill 320 Bakezori / * Kill 240 Chochin

Recompensa inclui item(ns) não especificado(s) pela wiki.', 'global', 'A', null, 187640, 0, 60, null),
  ('Cleanse the Remnants II', 'Cleanse the Remnants II is an A-Rank mission in the Land of Spirits, given by Rokuro.

Objetivos (wiki): * Kill 300 Tsuchigumo / * Kill 220 Karakasa

Recompensa inclui item(ns) não especificado(s) pela wiki.', 'global', 'A', null, 198410, 0, 60, null),
  ('Break the Chain', 'Part of the Land of Spirits Storyline, following The Memory Lane.
"The one behind the corruption does not work alone. Four enemies are hidden across the Land of Spirits. Help the villagers, complete their requests, and you will uncover where each one is hiding."

Objetivos (wiki): * Plan the Next Steps / * Eliminate Sound Ninjas (0/4)

Recompensa adicional (wiki): "consumables".', 'global', 'A', null, 490400, 0, 60, null),
  ('Cleanse the Forest I', 'A B-Rank story mission in the Land of Spirits, given by Nekomata in Yokai Village. It is the first of Nekomata''s forest-cleansing chain and is followed by Cleanse the Forest II.
"Nekomata has noticed yokai stirring in the forest and needs someone to deal with them. Head into the Spiritevil Falls and clear them out."

Objetivos (wiki): * Talk to Nekomata / * Head to Spiritevil Falls / * Kill 5 Red Betobeto / * Kill 10 White Betobeto / * Kill 30 Brown Betobeto / * Report back to Nekomata

Recompensa inclui item(ns) não especificado(s) pela wiki.', 'global', 'B', null, 220600, 50, 60, null),
  ('Balanced Waters', 'A Land of Spirits mission given by Nekomata, centered on restoring harmony to a river by fishing its two koi.
"The balance of this river has been disturbed."

Objetivos (wiki): * Fish Black Koi (0/1) / * Fish White Koi (0/1) / * Talk to Nekomata

Rank: não documentado pela wiki ("Information needed").

Nível: não documentado pela wiki ("Information needed").

Recompensa: não documentada pela wiki ("Information needed").', 'global', 'D', null, 0, 0, null, null),
  ('Cleanse the Forest II', 'A B-Rank story mission in the Land of Spirits, part of Nekomata''s forest-cleansing chain, following Cleanse the Forest I and followed by Cleanse the Forest III.
"More yokai have moved into the forest. Nekomata is sending you back in to thin out the numbers before they settle."

Objetivos (wiki): * Talk to Nekomata / * Head to Whispering Grove / * Kill 20 Bakezori / * Head to Yokai Riverbend / * Kill 40 Chochin / * Report back to Nekomata', 'global', 'B', null, 253500, 100, 60, null),
  ('Cleanse the Forest III', 'A B-Rank story mission in the Land of Spirits, part of Nekomata''s forest-cleansing chain, following Cleanse the Forest II and followed by Cleanse the Forest IV.
"The yokai in the forest aren''t letting up. Nekomata needs another sweep, head in and take them down."

Objetivos (wiki): * Talk to Nekomata / * Head to Spiritwind Ascent / * Kill 30 Karakasa / * Kill 50 Tsuchigumo / * Report back to Nekomata', 'global', 'B', null, 278500, 200, 60, null),
  ('Cleanse the Forest IV', 'A B-Rank story mission in the Land of Spirits, part of Nekomata''s forest-cleansing chain, following Cleanse the Forest III and followed by Cleanse the Forest V.
"Nekomata''s patience with the yokai presence in the forest is running out. Head deeper into the Grand Spiritfall and eliminate them."

Objetivos (wiki): * Talk to Nekomata / * Head to Grand Spiritfall / * Kill 60 Kappa / * Report back to Nekomata', 'global', 'B', null, 292500, 300, 60, null),
  ('Cleanse the Forest V', 'A B-Rank story mission in the Land of Spirits, the finale of Nekomata''s forest-cleansing chain, following Cleanse the Forest IV. It takes place in the oni cave behind the Goshinboku Tree, unsealed by The Whispering Well, and leads into a further mission that is still being documented.
"Nekomata wants the forest cleared for good. Take out the remaining yokai and put an end to it."

Objetivos (wiki): * Talk to Nekomata / * Head to Spiritstone Hollow / * Kill Red Oni / * Kill 5 Blue Oni / * Kill Black Oni / * Kill 10 Green Oni / * Kill Yellow Oni / * Kill Purple Oni / * Obtain 20 Oni Horn / * Report back to Nekomata / (kill counts for some of the oni are still being confirmed)', 'global', 'B', null, 316450, 500, 60, null),
  ('Botanical Research', 'Botanical Research is a Rank D story mission open to ninja from Level 12 upward. The village hospital wants plant samples from the surrounding area, and sends you out to collect them.

Objetivos (wiki): * Collect fresh berries and medicinal herbs from the area around the village / * Return them to Tasuke at the Leaf Village Hospital / The card names the two ingredient types but not their exact item names or the quantities required. The wiki carries Berries and Dried Herbs as candidates, though neither has been confirmed against this mission. If you have run it, please add the exact items and counts.

Recompensa adicional (wiki): "50 Ryo".', 'global', 'D', null, 7500, 50, 12, null),
  ('Hidden Seals', 'Hidden Seals.
Seals can be found within both Sand and Leaf territories. Within both villages there''s a mission to find that villages respective seals which upon completion will reward experience. Additionally, finding all seals of that respective village will unlock maps to be explored and, of course, grinded.', 'global', 'D', null, 0, 0, null, null),
  ('Guard the Barricades I', 'Upon meeting Guard Mika again at the Rebel Encampment in the Land of Iron, she gives you the task of killing 100 Emperor Penguins. Emperor penguins inhabit the Iron Cave and Iron Forest both of which can be found directly north of the Rebel Encampment.', 'global', 'A', null, 156500, 0, 50, null),
  ('Guard the Barricades II', 'When you meet Guard Tina at the Rebel Encampment she gives you the task of killing 100 Leopards. Leopards inhabit the Iron Forest in the Land of iron that can be found directly north of the Rebel Encampment.', 'global', 'A', null, 171500, 0, 52, null),
  ('Haiku 57-5', 'Upon talking to Master Zen at the Rebel Encampment in the Land of Iron, he tells you to obtain level 57 and then return to him to prove your worth. Upon returning, he asks you to construct a haiku of your own as a sort of final test to earn his favor.', 'global', 'D', null, 253100, 0, 50, null),
  ('Fill the Bucket', 'Upon speaking to Pakko at the Rebel Encampment in the Land of Iron, she asks you to play a game called "Fill the Bucket" you must run to each of the three wells located in the Land of iron and bring water from each well until the bucket is full. The first well can be found at the Rebel Encampment, while the second and third wells are within the Iron Forest, located north of the encampment. You will be able to monitor your progress via the indicator above your head when you begin the mission.', 'global', 'B', null, 238500, 0, 54, null),
  ('Dull Edges and Sharp Minds', 'You receive the mission from the Poster on Event Prizes house in Takumi Village.
You can find him upstairs of where you receive mission in Takumi, note he a boss, if you don''t see him you need to wait 30 minutes for him to respawn.', 'global', 'D', null, 0, 0, null, null),
  ('Haji''s Sword', '''''''Haji''s Sword is a Rank C story mission available from level 30 upward. Haji has lost his sword on the third floor of the Abandoned Lair and wants it brought back.
The Story Mission classification comes from the in-game mission card, captured 17 August 2026''''''. This page did not previously record it.

Objetivos (wiki): Not recorded. The Objectives panel on the captured card rendered empty, so no counter or step list is confirmed.

Recompensa adicional (wiki): "— see note".

Recompensa adicional (wiki): "60 Ryo; 25 Snake Venom".', 'global', 'C', null, 72300, 60, 30, null),
  ('Demon Claws', ':This page is about the mission. For the Taijutsu weapon of the same name, see Demon Claws.
Demon Claws is a Rank C story mission available from level 33 upward, given by Tomia on the Bears map. It shares its name with the Taijutsu weapon and is a different thing entirely.

Objetivos (wiki): * Defeat 40 Bears

Recompensa adicional (wiki): "30 Ryo; 5 Blood Pill I".', 'global', 'C', null, 140200, 30, 33, null),
  ('Gang War I', 'Overview: After completing the Stolen Train Keys mission and gaining access to the train, you are now tasked with a series of missions to help Koji Co. reach the Kawasaki Bridge construction site.
Mission Details: This is the first mission in the second series of missions in the level 20 arc. Your objective is to hunt down and defeat a number of formidable Gang Brawlers, known for their close combat skills and knockback attacks.
Location: Gang Brawlers can typically be found inside the train in the Land of Waves, specifically in both cabins: Front and Back.
Part of a longer Land of Waves mission chain (follows ''Access Granted'', continues into ''Gang War II'') not fully documented on the wiki yet.', 'global', 'B', null, 24000, 0, 20, null),
  ('Darker Places', 'The Leaf Village Innkeeper has tasked you with removing the seals hidden around the village, can you find them all?
Level 20

Objetivos (wiki): * Remove 4 seals / * Go to the Mysterious Apartment / * Go to the Mysterious Basement / * Return to the Innkeeper

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', 'folha', 30900, 0, null, null),
  ('Hidden in the Desert', 'The scroll in the abandoned building said something about finding and removing seals hidden in the desert, maybe you should check it out.
Level 20

Objetivos (wiki): * Remove 5 seals spread across the deserts / * Return to the Unsealing Scroll

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', 'areia', 30900, 0, null, null),
  ('Drunk Entry', 'Part of the Kinsen Mobsters Questline
Acquire a bottle of premium Sake and deliver it to the mobster guarding the club entrance.
Level 15

Objetivos (wiki): * Go To Kinsen Quarters Bar / * Obtain 2 Sake / * Deliver it', 'global', 'D', null, 12600, 0, null, null),
  ('Echos of Yokai I', 'Part of the Land of Spirits Storyline, following Binding Ofuda.
"Okuri is researching how the corruption is affecting the yokai across the land. He needs firsthand data but he can''t leave his post to get it. Scout the location he marked and bring back whatever the yokai leave behind."

Objetivos (wiki): * Scout Whispering Grove / * Return to Okuri / * Research Bakezori / * Report back to Okuri / * Obtain 10 Yokai Heart / * Obtain 40 Yokai Tongue', 'global', 'B', null, 268500, 0, 60, null),
  ('Echos of Yokai II', 'Part of the Land of Spirits Storyline, following Echos of Yokai I and followed by Echos of Yokai III. Can be accepted with a team.
"Okuri has tracked Chochin activity near Yokai Riverbend and needs to know their current state. Scout the location, use the soul flute, and bring back whatever they leave behind."

Objetivos (wiki): * Scout Yokai Riverbend (0/60s) / * Research Chochin (with the Soul Flute) / * Report back to Okuri / * Obtain 15 Yokai Heart / * Obtain 20 Chochin Lantern', 'global', 'B', null, 278600, 0, 60, null),
  ('Echos of Yokai III', 'Part of the Land of Spirits Storyline, following Echos of Yokai II and followed by Echos of Yokai IV.
"Okuri''s research leads him to a Karakasa sighting further into the land. He needs the same data as before - scout the location, use the soul flute, and collect the drops."

Objetivos (wiki): * Scout Spiritwind Ascent (0/120s) / * Research Karakasa (with the Soul Flute) / * Report back to Okuri / * Obtain 20 Yokai Heart / * Obtain 40 Yokai Eye / * Return to Okuri', 'global', 'B', null, 282550, 0, 60, null),
  ('Echos of Yokai IV', 'Part of the Land of Spirits Storyline, following Echos of Yokai III and followed by Echos of Yokai V.
"Okuri has identified Tsuchigumo presence at Spiritcore Crater. The area is dangerous but the data is critical. Scout it, use the soul flute, and bring back what the Tsuchigumo leave behind."

Objetivos (wiki): * Scout Spiritcore Crater (0/180s) / * Research Tsuchigumo (with the Soul Flute) / * Report back to Okuri / * Obtain 25 Yokai Heart / * Obtain 30 Tsuchigumo Fragment / * Obtain 30 Spirit Thread', 'global', 'B', null, 291600, 0, 60, null),
  ('Echos of Yokai V', 'Part of the Land of Spirits Storyline, following Echos of Yokai IV. It concludes Okuri''s research chain and leads into The Whispering Well.
"Okuri''s research is close to a conclusion. One more sample is needed - this time from a Kappa. Scout the location he marked, use the soul flute, and collect the drops to complete his findings."

Objetivos (wiki): * Scout Grand Spiritfall (0/240s) / * Research Kappa (with the Soul Flute) / * Report back to Okuri / * Obtain 30 Yokai Heart / * Obtain 40 Kappa Fragment', 'global', 'B', null, 306400, 0, 60, null),
  ('Help Sage find his way...', 'Help Sage find his way... is a one-time story mission added to Takumi Village in the 2026-07-09 patch. It is available from level 40+ and can be done by anyone, regardless of village.

Recompensa (texto da wiki): "New Title + Furniture (Poster)".', 'global', 'D', null, 0, 0, 40, null),
  ('Land Of Toads I', 'Land of Toads introduction missions: After getting level 30, toad hermit Hitsutomo will appear at your mission desk. He needs help at acquiring few things to get back home.', 'global', 'C', null, 90000, 0, 30, null),
  ('Land Of Toads II', null, 'global', 'B', null, 186500, 0, 30, null),
  ('Obtain Talons', 'To start those missions you need to talk with Hoshitomo.', 'global', 'C', null, 81800, 0, 30, null),
  ('Obtain Feathers', null, 'global', 'C', null, 81800, 0, 30, null),
  ('Obtain Raccoon Tails', null, 'global', 'C', null, 81800, 0, 30, null),
  ('Natural Enemies I', 'To start those missions you need to talk with Momotomo. First mission you get from Momotomo is killing 50 Hawks, you can find them at west and east side of mountain.

Recompensa adicional (wiki): "4 toad oils".', 'global', 'B', null, 20400, 0, 30, null),
  ('Natural Enemies II', 'Recompensa adicional (wiki): "8 Toad oils".', 'global', 'B', null, 40800, 0, 30, null),
  ('Resolving an Argument', 'Satomo had an argument with Yoshitomo, help Satomo to uncover the truth. Reworked 10 September 2026: it is now a jump quest through his house (beware of traps).', 'global', 'D', null, 163600, 0, 30, null),
  ('Okada''s Debt', 'An exciting and fun gambling challenge!', 'global', 'D', null, 177777, 0, null, null),
  ('Honey Hive Hunt', 'Ayako the bee keeper from the Kinsen Quarters needs your help in producing her next batch of honey!

Nota da recompensa (wiki): "22,500 (both levels)".', 'global', 'C', null, 22500, 0, null, null),
  ('Panda Food is Penguin Beaks!?', 'Upon meeting Yozune at the Rebel Encampment in the Land of Iron, he gives you the task of collecting penguin beaks to feed his adorable pet panda. Penguin beaks are obtainable from Emperor Penguins that inhabit both the Iron Cave and Iron Forest.', 'global', 'B', null, 168700, 0, 51, null),
  ('Ninja Evergarden', 'Upon meeting Old Man Hideyoshi at the Rebel Encampment in the Land of Iron, he expresses his longing for his grandson Saburo and asks you to help finish and deliver a letter to him, in the Samurai armory inside Iron City.', 'global', 'A', null, 242900, 0, 55, null),
  ('Hide & Seek', 'Mission is accepted by an NPC called Miki located at playground center of the Hidden Leaf village. You''re tasked with playing Hide & Seek with Miki, Kimi, and Oku.', 'global', 'D', null, 0, 0, null, null),
  ('Light Work', 'Light Work is a mission available to take from level 43+. To get this mission you need to go to Bandit Bridge and find NPC called Kodaku. Kodaku wants you to get him 5 Gray Bear Paws, which drop from Glacial Bear.

Recompensa adicional (wiki): "200 ryo".', 'global', 'C', null, 75400, 200, 43, null),
  ('Old Blood Puppet Retirement', 'A puppeteer ninja once used his own blood to transfer chakra into puppets that now inhabit an abandoned workshop North-West of the Sand Village.', 'global', 'A', null, 0, 0, null, null),
  ('Hidden Tomb', 'Yuu promised to tell you the secret of Takumi if you helped her remove 7 seals around the village. Level 25. A fuller step-by-step walkthrough of the seal hunt and the tomb boss fight is kept on the wiki''s Yuu Mini Questline page.

Objetivos (wiki): * Unseal 7 Seals in Takumi Village / * Go To Tomb of Royalty / * Return to Yuu

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', null, 68000, 0, null, null),
  ('Mobster Take Out', 'Part of the Kinsen Mobsters Questline
A debt-evading mobster gang is hiding in Kinsen Quarters. Find them and take out the gang underlings to weaken their hold.
Level 15

Objetivos (wiki): * Find a way into Mobster Hideout (Complete Drunk Entry) / * Kill 50 Mobsters', 'global', 'B', null, 23600, 0, null, null),
  ('Kairi''s Parcel', 'Kairi has a parcel that she needs collected for Ritsuko in Kinsen Quarters, the home of the Fire Daimyo in the Land of Fire, west of the Leaf Village.
Level 22

Objetivos (wiki): * Go To Kinsen Quarters / * Get Parcel from Ritsuko / * Return to Kairi

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', null, 18200, 0, null, null),
  ('Land of Spirits', 'Part of the Land of Spirits Storyline
"You have arrived at the Land of Spirits. Beyond the old torii gate, a path leads toward Yokai Village and somewhere inside, a Fox Princess is waiting."

Objetivos (wiki): * Head to Yokai Village / * Talk to Lady Kitsune', 'global', 'B', null, 240850, 0, 60, null),
  ('Lucky Coin', 'Part of the Land of Spirits Storyline (side mission).
"The spirit board has spoken. A coin tossed into the fountain may bring fortune to those who seek it. Find the coin and make your toss. The water has been waiting for an offering."

Objetivos (wiki): * Obtain 1 Yokai Coin (0/1) / * Toss a coin into the Fountain (choose your wish)

Recompensa adicional (wiki): "title "Lucky One"".', 'global', 'B', null, 395400, 0, 64, null),
  ('Hornet Infestation', 'Hornet Infestation is a repeatable daily mission of Rank C, available to ninja between Level 25 and 33.

Objetivos (wiki): * Kill Hornets in the areas around Kinsen Quarters and Takumi Village

Recompensa adicional (wiki): "105 Ryo".', 'diaria', 'C', null, 69750, 105, 25, null),
  ('Poisonous Hunger', 'Poisonous Hunger is a C Rank story mission. Zabuto will hand over a crafting recipe, but he wants feeding first.

Objetivos (wiki): * Collect 500 Ryo / * Obtain 5 Prawn Sushi (0/5) / The 500 Ryo is a cost you pay rather than a reward.

Nível real da wiki: "Story Mission" (formato não padronizado).

Recompensa adicional (wiki): "A crafting recipe from Zabuto".', 'global', 'C', null, 21400, 0, null, null),
  ('The Venomous Requirement', 'The Venomous Requirement is a mission available to take from level 25+. To get this mission you need to go to Snake Lair and find NPC called Ko. Ko wants you to get him 50 snake venoms, they drop from Snakes. After completing mission he will let you use a teleport seal to the upper level of Snake Lair (needs Body Flicker to use it).

Recompensa adicional (wiki): "Unlocks Venomous Snake floor.".', 'global', 'C', null, 77100, 0, 25, null),
  ('Yozo the Bozo', 'A challenge to some of the most dedicated gamblers in Kinsen. You''re tasked with helping the broke boy Yozo who was looking to feed his family but lost his money in gambling. You''re his only hope, go and win his money back!', 'global', 'D', null, 37777, 0, null, null),
  ('Sansan''s Gold', 'Mission is accepted by an NPC called Sansan located in Totori Village, west of the Hidden Mist village. You''re tasked with finding 3 gold bars thrown in bodies of water around the mist village and bringing them back to Sansan.

Recompensa adicional (wiki): "Cloak of Invisibility Manual".', 'global', 'D', null, 300, 0, 4, null),
  ('The Fur maniac', 'Upon speaking to Daiken, at the Rebel Encampment in the Land of Iron, he gives the task of gathering 50 of each type of fur: Wolf fur (from Alpha Wolves at Chilly Pass), Tiger fur (from Tigers), and Fox fur (from Foxes near the Windy Pond east of the Mist Village).', 'global', 'B', null, 148700, 0, 51, null),
  ('Stronger than the Samurai I', 'Upon speaking to Yin at the Rebel Encampment in the Land of Iron, he gives you a quest to prove your strength: kill 200 Samurai and collect 80 iron pieces (dropped by Samurai and Horned Samurai in Iron City).', 'global', 'A', null, 247700, 0, 56, null),
  ('Stronger than the Samurai II', 'Upon speaking to Yang at the Rebel Encampment in the Land of Iron, she gives you a quest to prove your strength: kill 180 Horned Samurai and collect 80 iron pieces (dropped by Samurai and Horned Samurai in Iron City).', 'global', 'A', null, 263100, 0, 57, null),
  ('Rescue grandpa Iroh', 'Upon talking to Suki at the Rebel Encampment in the Land of Iron, she pleads with you to rescue her grandfather Iroh, imprisoned in Iron City and overseen by Samurai. You must obtain an Iron Key from a Horned Samurai to free him.

Recompensa adicional (wiki): "Ryo".', 'global', 'A', null, 277700, 0, 56, null),
  ('Talk to the Rebel Leader', 'Upon talking to Guard Mika at your village mission desk, she gives you the task of speaking to Chief Uzan, at the Rebel Encampment in the Land of Iron (accessible via the Summoning Toad in your village).', 'global', 'D', null, 10000, 0, 50, null),
  ('The Iron Tower', 'After completing the Rebel Camp Storyline and speaking to Chief Uzan, you are tasked with infiltrating Iron Tower in Iron City and defeating the corrupted leader of the Samurai.', 'global', 'S', null, 273100, 0, 57, null),
  ('Seeker of Truth', 'After unveiling the hidden cave, you found a broken seal with a riddle carved on the wall beside the gate: ''Seek the 7 truths and lay in death''s own view''. Level 10.

Objetivos (wiki): * Kill 7 Guardian Spirits / * Find a way to enter the Tomb / * Go To the Royal Tomb

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', null, 2500, 0, null, null),
  ('The Mob Boss', 'Part of the Kinsen Mobsters Questline
With his crew wiped out, the mob boss Shizu is vulnerable. Track him down, eliminate him and let Takabe know the job is done.

Objetivos (wiki): * Kill Shizu

Rank real da wiki: "Main" (missão principal de storyline, fora da escala S/A/B/C/D).', 'global', 'S', null, 47800, 0, null, null),
  ('Remnants of the Wicked I', 'Remnants of the Wicked I is an A-Rank mission in the Land of Spirits, given by Rokuro.

Objetivos (wiki): * Obtain 120 Yokai Heart / * Obtain 80 Yokai Eye / * Obtain 70 Yokai Tongue

Recompensa inclui item(ns) não especificado(s) pela wiki.', 'global', 'A', null, 178610, 0, 60, null),
  ('The Memory Lane', 'Part of the Land of Spirits Storyline.
"Kitsune has given you a fragment of the land''s own memory. Something buried deep is trying to surface and it chose you to witness it. Whatever waits inside, face it."

Objetivos (wiki): * Witness the Memory / * Confront the presence within it / * Eliminate the Threat (0/20) / * Report back to Lady Kitsune', 'global', 'A', null, 303000, 800, 60, null),
  ('The Well', 'The Well is a seal-and-puzzle mission. It tasks the player with finding four seals scattered across the world, then solving a well puzzle. (Not yet confirmed as a full arc; page name may change.)', 'global', 'D', null, 0, 0, null, null),
  ('The Whispering Well', 'Part of the Land of Spirits Storyline, following Echos of Yokai V. The talking well in the middle of Yokai Village holds the power to break the seal that Okuri''s research uncovered. A further mission follows it and is still being documented.
"The seal blocking the cave cannot be broken by force alone. The Whispering Well holds the power to shatter it but it needs Spirit Orbs to do so. Collect Spirit Orbs and deposit them into the well."

Objetivos (wiki): * Collect 80 Spirit Orbs / * Bring the Orbs to the Well', 'global', 'A', null, 400500, 0, 60, null),
  ('Scattered Report', 'Scattered Report is a Level 10+ D-rank story mission available in all three villages, added in the Update v5.13.5 patch (2 August 2026).

Objetivos (wiki): * Find the missing pages (0/4) / * Return to the Jonin / Taken from and returned to the Jonin by the Notice Board just outside the village gate. The four pages lie on the ground in maps outside the village.

Recompensa adicional (wiki): "100 Ryo".', 'global', 'D', null, 7000, 100, 10, null)
on conflict (name, coalesce(village_id, '')) do update set
  description = excluded.description,
  mission_type = excluded.mission_type,
  rank = excluded.rank,
  xp = excluded.xp,
  ryo = excluded.ryo,
  level_min = excluded.level_min,
  level_max = excluded.level_max;

-- Migração 018: cadastro das Organizações (Corps) oficiais do jogo e dos
-- itens restritos por cargo/organização, extraídos de
-- https://ninonline.fandom.com/wiki/Corps,
-- https://ninonline.fandom.com/wiki/Kuronami_Organization,
-- https://ninonline.fandom.com/wiki/Medical_Corps,
-- https://ninonline.fandom.com/wiki/Military_Police e
-- https://ninonline.fandom.com/wiki/Role-gated_equipment.
--
-- Tabela nova `organizations`: 8 organizações --  ANBU, Twelve Guardian
-- Ninja, The Sand Puppet Brigade, Seven Swordsmen of the Mist, The
-- Neo-Akatsuki, Military Police Force, Medical Corps e Kuronami.
--
-- Fora de escopo: a página "Organizations" da wiki também lista 5
-- organizações feitas por JOGADORES (Desert Pirates, Yoru, Taka, Red
-- Lotus, Seigi) -- são história/trivia de servidor (grupos que já não
-- existem mais), não um sistema do jogo ativo hoje, então ficaram de
-- fora. As 8 cadastradas aqui são as oficiais, criadas por admin, que
-- ainda funcionam como mecânica (squads, ranks, itens restritos).
--
-- `village_id`: null quando a organização existe nas 3 vilas (Military
-- Police Force, Medical Corps), é secreta/cross-vila (ANBU, Neo-
-- Akatsuki), ou é baseada numa vila que não está na tabela `villages`
-- (Kuronami, baseada em Takumi Village -- Takumi não é uma das 4 vilas
-- jogáveis cadastradas ali). Preenchido só quando a organização é
-- exclusiva de uma vila específica das 4 (Twelve Guardian Ninja =
-- Folha, The Sand Puppet Brigade = Areia, Seven Swordsmen of the Mist
-- = Névoa).
--
-- `secret`: true pra ANBU e Neo-Akatsuki -- a wiki diz explicitamente
-- que organizações secretas não aparecem no bounty book do jogador.
-- Kuronami não tem essa confirmação explícita na wiki, então ficou
-- `false` mesmo sendo uma organização criminosa.
--
-- `ranks`: lista ordenada (menor pro maior) só quando a wiki documenta
-- uma hierarquia formal (ANBU, Puppet Brigade, Military Police).
-- Twelve Guardian Ninja e Seven Swordsmen explicitamente NÃO têm
-- ranks/esquadrões formais (a wiki diz isso) -- ficou vazio de
-- propósito, não é lacuna de dado. Neo-Akatsuki e Medical Corps não
-- têm uma lista de ranks documentada -- também ficou vazio.
--
-- Itens restritos (10, todos já listados na tabela da página
-- "Role-gated equipment"): 9 já existiam em `items` como `type =
-- 'roupa'` (cadastrados pela migração 015 como placeholders com
-- descrição genérica "This is role-gated...") -- esta migração
-- enriquece essas 9 linhas em vez de recriá-las: preenche descrição
-- completa, `restricted_to` e (só pros que dão bônus) `restricted_
-- stat_bonus`/`restricted_notes`. O décimo (Kuronami Ring) não existia
-- -- a migração 013 (anéis) deixou ele explicitamente fora de escopo
-- por ser restrito a organização -- entra aqui como `type = 'anel'`
-- novo, com as colunas `ring_*` da migração 013.
--
-- Três colunas novas em `items`, nulas pra item comum:
--   - restricted_to: quem pode equipar (organização, rank ou clã),
--     texto livre -- ex. "Mist Special Division", "Chunin", "Clã
--     Tendo".
--   - restricted_stat_bonus: bônus de atributo em JSON, só quando o
--     item dá bônus (a imensa maioria destes é puramente cosmética/de
--     status -- só a Mist Special Division Mask dá stats de verdade
--     entre as 9 roupas; o Kuronami Ring já tem bônus em `ring_
--     variants`, então esta coluna fica nula nele).
--   - restricted_notes: mecânica extra (ex. "não pode ser trocado" nas
--     regalias do Mizukami, "cai ao morrer" no Kuronami Ring -- texto
--     do próprio jogo, não nota da wiki) ou aviso de que o nível
--     exigido no card é baixo o bastante pra ser irrelevante perto do
--     requisito real (rank/organização).
--
-- "Tendo Beserker Pants": grafia "Beserker" (não "Berserker") é a
-- grafia do próprio jogo, mantida como está no nome do item.
--
-- Kuronami Ring -- nota de nomenclatura não resolvida: o nome do item
-- ("Kuronami Ring") e o efeito visual no jogo ("KuronamiGlow") usam o
-- nome da organização Kuronami, mas o texto da própria wiki diz que é
-- "worn only by the Neo-Akatsuki" e dropa na "Neo-Akatsuki cave" --
-- inconsistência da wiki entre o nome do item e a organização que o
-- usa, mantida como está (restricted_to segue o texto: Neo-Akatsuki).
--
-- Lacunas de dados: a forma de conseguir a maioria destes itens não é
-- documentada pela wiki (cargos/organizações concedem o item
-- automaticamente a membros, sem loja/NPC) -- `clothing_source` fica
-- null nesses casos em vez de um chute.

create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  village_id text references villages(id) on delete set null,
  description text,
  ranks text[] not null default '{}',
  secret boolean not null default false,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists organizations_village_id_idx on organizations (village_id);
create unique index if not exists organizations_name_unique_idx on organizations (lower(name));

insert into organizations (name, village_id, description, ranks, secret) values
  ('ANBU', null, 'The top-secret squads in each village, including some of the best fighters, acting as the private guards of the Kage. In Mist they are called Hunter-Nin. Joining is very hard: you must be close to the Kage and have proven your loyalty and fighting skill in the village.', array['Squad Member', 'Squad Captain', 'Second in Command (SiC)', 'Leader'], true),
  ('Twelve Guardian Ninja', 'folha', 'The bodyguards appointed to guard the Daimyo of the Land of Fire, based at the summit of the Leaf Village. Unlike most organizations they act as one group rather than being split into squads, led by one skilled leader (the organization leader) on missions and hunts. They have a sub-group called the "Proteges", potential future members in training. Famous for wearing a unique waistcloth marked with the kanji for fire (火).', array[]::text[], false),
  ('The Sand Puppet Brigade', 'areia', 'A unit of Sand shinobi specialized in using giant puppets as weapons to defend the village and fight enemies, summoned via a specialized puppet coffin. Split into squads of 3 with a captain, composed of the most strategic and talented combatants.', array['Squad Member', 'Squad Captain', 'Leader'], false),
  ('Seven Swordsmen of the Mist', 'neblina', 'An organization of the deadliest, most blood-thirsty shinobi of the Hidden Mist Village. More a title than a group -- members do not operate together, usually hunting solo or in groups of up to 3. Famous for wielding the Seven Legendary swords of the Mist, one per member. You join by winning a blood duel against a current member (taking their place and sword) or by being invited to a free spot after proving yourself.', array[]::text[], false),
  ('The Neo-Akatsuki', null, 'The most infamous criminal organization in the Ninja World, consisting of the most dangerous missing-nin, based in Takumi. Organized into two-person teams with a leader per team, formed by compatibility between members. Joined via duel challenge or by being hand-picked for combat skill and high bounty. Each member holds a ring that grants an ominous red aura and a severe strength boost.', array[]::text[], true),
  ('Military Police Force', null, 'The Military Police Forces (LMPF in Leaf, SMPF in Sand, MMPF in Mist) bring justice to the village, punish criminals, investigate crimes and support the Kage. Has a special jutsu that jails a criminal for 30 minutes in the police HQ prison, usable only by ranked ninja such as Chunin and above.', array['Crime Investigator/Analyst', 'Police Captain', 'Deputy Chief', 'Chief General'], false),
  ('Medical Corps', null, 'Village organizations dedicated to healing and supporting fellow ninja, one per major village, operating from a medical base (hospital). Members focus on the Medical mastery and gain access to exclusive daily missions (healing and reviving allied players) for XP and Ryo.', array[]::text[], false),
  ('Kuronami', null, 'A criminal organization formed from the ideology of its predecessor, based in Takumi Village. Members take on paid jobs in exchange for Ryo, including helping with missions, open to members of any village or other organization (12 member slots documented).', array[]::text[], false)
on conflict (lower(name)) do update set
  village_id = excluded.village_id,
  description = excluded.description,
  ranks = excluded.ranks,
  secret = excluded.secret;

drop trigger if exists organizations_set_updated_at on organizations;
create trigger organizations_set_updated_at before update on organizations for each row execute function set_updated_at();
alter table organizations enable row level security;
drop policy if exists organizations_public_read on organizations;
create policy organizations_public_read on organizations for select using (true);
drop policy if exists organizations_auth_write on organizations;
create policy organizations_auth_write on organizations for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

alter table items add column if not exists restricted_to text;
alter table items add column if not exists restricted_stat_bonus jsonb;
alter table items add column if not exists restricted_notes text;
create index if not exists items_restricted_to_idx on items (restricted_to);

-- Enriquecimento das 9 roupas role-gated já cadastradas pela migração
-- 015 (placeholders com descrição genérica) -- atualiza só linhas que
-- já são 'roupa', nunca cria linha nova aqui.
insert into items (name, type, description, clothing_slot, clothing_rarity, clothing_level_required, clothing_source, clothing_notes, restricted_to, restricted_stat_bonus, restricted_notes) values
  ('Mist Special Division Mask', 'roupa', 'A mask worn by Mist Special Division to hide their identities and offer some protection.', 'Hat', 'Enchanted', 5, null, 'Forma de ingresso na Mist Special Division não documentada pela wiki.', 'Mist Special Division (Névoa)', '{"Strength": 7, "Fortitude": 7, "Intellect": 7, "Agility": 7, "Chakra": 7}'::jsonb, 'O nível 5 no card não é o requisito real -- o item só pode ser equipado por quem tem o cargo de Mist Special Division (o card também lista a vila Mist). Maior bônus de atributo entre os itens catalogados nesta migração (+7 em todos os 5 atributos, +35 no total).'),
  ('Mist Special Division Robe', 'roupa', 'Robe worn by the Mist Special Division Corps of the Mist village.', 'Vest', 'Common', null, null, 'Forma de ingresso na Mist Special Division não documentada pela wiki.', 'Mist Special Division (Névoa)', null, 'Não dá bônus de atributo -- o bônus do uniforme está inteiro na Mist Special Division Mask.'),
  ('Mizukami Hat', 'roupa', 'A hat worn by the leader of the Mist Village during ceremonies and meetings to show his authority.', 'Hat', 'Legendary', null, null, null, 'Mizukage (líder da vila Névoa)', null, 'Regalia do cargo, não item de combate -- marcado "Cannot be traded" no card: só quem ocupa o cargo pode usar, e não pode ser repassado a outro jogador.'),
  ('Mizukami Cloak', 'roupa', 'A cloak worn by the leader of the Mist Village during ceremonies and meetings to show his authority.', 'Vest', 'Legendary', null, null, null, 'Mizukage (líder da vila Névoa)', null, 'Regalia do cargo, não item de combate -- marcado "Cannot be traded" no card: só quem ocupa o cargo pode usar, e não pode ser repassado a outro jogador.'),
  ('Sand Police Vest', 'roupa', 'A police uniform (Only equippable by Sand Police Force members)', 'Vest', 'Common', null, null, 'Forma de ingresso no Sand Police Force não documentada pela wiki.', 'Sand Police Force (Areia)', null, 'O card carrega a tag "Authority".'),
  ('Yamato Protector', 'roupa', 'This forehead protector comes with a metal piece around the face for added protection. Wearing one is a sign of mutual respect as ninjas in combat.', 'Hat', 'Uncommon', null, null, null, 'Chunin (Folha)', null, 'Restrito por rank (Chunin) e vila (Folha), não por nível.'),
  ('Black Flak Jacket', 'roupa', 'A flak jacket, designed to give added protection to the upper body and the vital areas residing there.', 'Vest', 'Uncommon', 5, null, null, 'Jonin', null, 'O nível 5 no card é irrelevante -- o requisito real é o rank Jonin.'),
  ('White Chunin Battle Suit', 'roupa', 'A white robe fitted with straps of charred leather for added protection.', 'Shirt', 'Uncommon', 30, null, null, 'Chunin (Areia)', null, 'Restrito por rank (Chunin), nível (30) e vila (Areia) ao mesmo tempo -- diferente da maioria dos itens role-gated cadastrados aqui, que restringem só por um critério.'),
  ('Tendo Beserker Pants', 'roupa', 'A pair of pants that is worn by the Tendo Clan elites.', 'Pants', 'Unique', 30, null, null, 'Clã Tendo (elite)', null, 'Grafia "Beserker" (não "Berserker") é a grafia do próprio jogo, mantida como está no nome do item.')
on conflict (lower(name)) do update set
  description = excluded.description,
  clothing_slot = excluded.clothing_slot,
  clothing_rarity = excluded.clothing_rarity,
  clothing_level_required = excluded.clothing_level_required,
  clothing_source = coalesce(items.clothing_source, excluded.clothing_source),
  clothing_notes = excluded.clothing_notes,
  restricted_to = excluded.restricted_to,
  restricted_stat_bonus = excluded.restricted_stat_bonus,
  restricted_notes = excluded.restricted_notes
where items.type = 'roupa';

-- Kuronami Ring: décimo item restrito, fora de escopo da migração 013
-- (anéis) por ser restrito a organização -- entra aqui como novo `type
-- = 'anel'`.
insert into items (name, type, description, ring_family, ring_level_required, ring_variants, ring_notes, restricted_to, restricted_notes) values
  ('Kuronami Ring', 'anel', 'A ring worn only by the Neo-Akatsuki, the strongest and most evil ninja. It creates an ominous aura around the wielder and grants them immense power, increasing all their stats greatly. It can only be obtained from the Neo-Akatsuki cave, accessible only to the organization''s members.', 'Kuronami Ring', 35, '[{"rarity": "Legendary", "stats": {"Strength": 20, "Fortitude": 30, "Intellect": 20, "Agility": 20, "Chakra": 20}}]'::jsonb, 'Anéis são cosmeticamente invisíveis -- não mudam a aparência do personagem, só dão bônus de atributo (este, além disso, dá uma aura visual ao redor do personagem).', 'Neo-Akatsuki (membro)', 'Cai ao morrer ("Drops on death", texto do próprio jogo). Obtido só na Neo-Akatsuki cave, acessível apenas a membros. Nota de nomenclatura: o nome do item ("Kuronami Ring") e o efeito visual ("KuronamiGlow") usam o nome da organização Kuronami, mas o texto da própria wiki diz que é usado pelo Neo-Akatsuki -- inconsistência da wiki não resolvida aqui.')
on conflict (lower(name)) do update set
  description = excluded.description,
  ring_family = excluded.ring_family,
  ring_level_required = excluded.ring_level_required,
  ring_variants = excluded.ring_variants,
  ring_notes = excluded.ring_notes,
  restricted_to = excluded.restricted_to,
  restricted_notes = excluded.restricted_notes
where items.type = 'anel' or items.type = 'item_mob';

-- Migração 019: cadastro dos itens da Cash Shop (loja de Nin Credits/NC),
-- extraídos de https://ninonline.fandom.com/wiki/Cash_Shop e das páginas
-- que ela referencia: Outfits, Premium Hairstyles, Skins & Eyes, Cash
-- Shop Game Items e Furniture.
--
-- Duas colunas novas em `items`, nulas pra item comum:
--   - price_nc: preço em Nin Credits (NC), a moeda paga da Cash Shop.
--     Usada em vez de `clothing_price_ryo`/`clothing_price_text` (que
--     cobrem preço em Ryo ou o USD histórico do Cash Shop antigo,
--     migração 015) porque é um número, pesquisável, e se aplica tanto
--     a roupas quanto a consumíveis desta migração.
--   - price_nc_notes: detalhes do card da Cash Shop que não cabem em
--     `price_nc` -- stack size, se pode ser trocado/destruído, ou (pros
--     hairstyles) a atualização e o artista que a wiki documenta.
--
-- 353 linhas entram/são enriquecidas nesta migração:
--
-- 1) Outfits (215 itens de
--    https://ninonline.fandom.com/wiki/Outfits, incluindo as sub-seções
--    "Pals (Companions)" e "Functional", ver itens 2 e 3 abaixo): 36 já
--    existiam em `items` como `type = 'roupa'` da migração 015
--    (cadastrados com preço em USD do Cash Shop antigo, entre eles o
--    Rat Pal) -- essas só ganham `price_nc` preenchido, sem tocar em
--    descrição/raridade/preço em USD já cadastrados. As outras 179 são
--    novas.
--
--    `clothing_slot` aqui é a seção da própria página da wiki (ex.
--    "Vests, Robes & Body", "Hats & Head", "Masks & Eyewear") em vez de
--    um slot por item -- a página lista só ícone/nome/preço por item,
--    sem detalhar o slot de equipamento individual como as páginas
--    dedicadas faziam na migração 015; usar a seção como veio da wiki é
--    mais honesto que inferir um slot que a fonte não documenta.
--
--    `description` fica null pra todas as novas -- a página lista só
--    ícone, nome e preço, sem texto de descrição por item (diferente
--    das páginas dedicadas de item usadas nas migrações anteriores).
--
-- 2) Pals (8, sub-seção "Pals (Companions)"): cosméticos de companion
--    que seguem o personagem. Uma delas, Rat Pal, já existia (migração
--    015, `clothing_slot = 'Pet'`) -- as outras 7 entram novas com o
--    mesmo `clothing_slot = 'Pet'`, seguindo o precedente já registrado.
--
-- 3) Functional (6, sub-seção "Functional": Merchant Cart, Summoner
--    Scroll, 4 Military Carrier Scrolls de cor, todas novas):
--    cosméticos "de utilidade" que não são nem roupa no sentido usual
--    nem consumível de uso único -- a wiki não documenta o que cada um
--    faz além do nome/preço. Entraram como `type = 'roupa'`,
--    `clothing_slot = 'Functional'`, sem inventar uma descrição de
--    mecânica que a wiki não dá.
--
-- 4) Premium Hairstyles (151, de
--    https://ninonline.fandom.com/wiki/Premium_Hairstyles: 136 a 890 NC
--    + 15 básicas a 260 NC): nenhuma existia antes -- hairstyles nunca
--    tinham sido cadastradas. Entram como `type = 'roupa'`,
--    `clothing_slot = 'Hairstyle'`. Quando a wiki documenta a
--    atualização/artista de uma hairstyle específica, isso vai pro
--    `price_nc_notes` (a maioria não tem essa informação -- a wiki
--    mesma deixa em branco).
--
-- 5) Skins & Eyes (10, de
--    https://ninonline.fandom.com/wiki/Skins_%26_Eyes): mudam skin do
--    corpo, cor/estilo de olho ou cor da montaria -- são "aplicados"
--    uma vez, não equipados num slot permanente, então entraram como
--    `type = 'consumivel'` em vez de `'roupa'`.
--
-- 6) Cash Shop Game Items (10, de
--    https://ninonline.fandom.com/wiki/Cash_Shop_Game_Items): itens de
--    conta/utilidade (Name Changer, Scroll of Stat Reset, Inventory
--    Expansion, World Blessings, etc.) -- `type = 'consumivel'`. O "New
--    Ninja Free Gift" é gratuito (a wiki marca "Free", não um valor em
--    NC) -- `price_nc` ficou null com a nota explicando.
--
-- 7) Furniture (só os 3 itens realmente vendidos na Cash Shop: Grand
--    Piano, Palace Pillar, White Neo Cash Register). A categoria
--    Furniture da wiki tem 9 páginas no total, mas 6 ficaram FORA desta
--    migração por não serem itens de Cash Shop: Battlefield Memorial,
--    War Banner e War Pillar vêm da War Event Shop (moeda/evento
--    diferente); Chateau Bookshelf II e Dark Monkey King Trophy não têm
--    fonte de Cash Shop documentada (o segundo é drop de mob); e
--    Toranin Store é craftável (não comprável). Os 3 itens cadastrados
--    entram como `type = 'roupa'`, `clothing_slot = 'Furniture'`,
--    seguindo o mesmo padrão usado pra Pals/Functional -- mobília não é
--    "vestível" no sentido literal, mas reaproveita a mesma coluna em
--    vez de criar uma tabela nova só pra 3 linhas.
--
-- Fora de escopo desta migração: os itens ligados de Furniture, War
-- Event, mob drop e crafting citados acima (pertencem a outros sistemas
-- e podem virar seu próprio cadastro depois).

alter table items add column if not exists price_nc integer;
alter table items add column if not exists price_nc_notes text;
create index if not exists items_price_nc_idx on items (price_nc);

-- ---------------------------------------------------------------
-- Outfits (incl. Pals e Functional): 179 itens novos
-- ---------------------------------------------------------------

insert into items (name, type, description, clothing_slot, clothing_price_text, clothing_source, price_nc) values
  ('Full Metal Arm', 'roupa', null, 'Accessories', '890 NC', 'Cash Shop', 890),
  ('Regal Shoulderguard', 'roupa', null, 'Accessories', '440 NC', 'Cash Shop', 440),
  ('5 O''Clock Shadow', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Large Crescent Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Moustache Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Playboy Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Sensei Beard', 'roupa', null, 'Beards & Facial Hair', '890 NC', 'Cash Shop', 890),
  ('Injustice Cape', 'roupa', null, 'Capes', '890 NC', 'Cash Shop', 890),
  ('Arctic Fox Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & Pink Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & Pink Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & White Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black & White Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Black Fox Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Bunny Ears', 'roupa', null, 'Ears, Tails & Animal Features', '740 NC', 'Cash Shop', 740),
  ('Mystic Fox Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Orange Fox Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Black Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Blue Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Blue Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Pink Cat Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('White & Pink Cat Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Wolf Ears', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Wolf Tail', 'roupa', null, 'Ears, Tails & Animal Features', '890 NC', 'Cash Shop', 890),
  ('Blue Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Green Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Merchant Cart', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Purple Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Red Military Carrier Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Summoner Scroll', 'roupa', null, 'Functional', '890 NC', 'Cash Shop', 890),
  ('Black Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Black Cat Ear Bucket Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Black Sailor Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Dark Blue Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Flytrap Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Gray Cat Ear Bucket Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Green Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Pink Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Pink Cat Ear Bucket Hat', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Purple Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Red Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Royal Crown', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('Royal Tiara', 'roupa', null, 'Hats & Head', '890 NC', 'Cash Shop', 890),
  ('White Cap', 'roupa', null, 'Hats & Head', '440 NC', 'Cash Shop', 440),
  ('Yellow Ducky Bucket Hat', 'roupa', null, 'Hats & Head', '710 NC', 'Cash Shop', 710),
  ('Black Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Blue Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Green Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Pink Cute Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Purple Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Red Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Yellow Stylish Headphones', 'roupa', null, 'Headphones', '890 NC', 'Cash Shop', 890),
  ('Beige Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Black Cat Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Black Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Blue Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Dark Fox Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Fox Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Fur Collared Beige Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Beige Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Black Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Black Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Black Jacket C', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Blue Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Blue Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Red Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Fur Collared Red Jacket B', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Orange Cat Hoodie', 'roupa', null, 'Jackets & Coats', '890 NC', 'Cash Shop', 890),
  ('Red Jacket', 'roupa', null, 'Jackets & Coats', '710 NC', 'Cash Shop', 710),
  ('Beige Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Black Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Blue Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Brown Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Gray Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Green Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Green Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Orange Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Peach Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Red Katahada Kimono', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('White Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Yellow Party Dress', 'roupa', null, 'Kimono & Dresses', '890 NC', 'Cash Shop', 890),
  ('Black Goggles', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Blue Goggles', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Blue Power Detection Scopes', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Clear Big Round Glasses', 'roupa', null, 'Masks & Eyewear', '710 NC', 'Cash Shop', 710),
  ('Clear Visor', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Eye Scope', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Eye Wrapping Bandage', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Gray Face Mask', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Green Power Detection Scopes', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Inoshishi Mask', 'roupa', null, 'Masks & Eyewear', '890 NC', 'Cash Shop', 890),
  ('Red Power Detection Scopes', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Steel Visors', 'roupa', null, 'Masks & Eyewear', '890 NC', 'Cash Shop', 890),
  ('Tinted Big Round Glasses', 'roupa', null, 'Masks & Eyewear', '710 NC', 'Cash Shop', 710),
  ('White Face Mask', 'roupa', null, 'Masks & Eyewear', '440 NC', 'Cash Shop', 440),
  ('Wooden Summon Mask', 'roupa', null, 'Masks & Eyewear', '890 NC', 'Cash Shop', 890),
  ('Fish Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Kitty Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Monkey Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Owl Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Piggy Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Puppy Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Sluggy Pal', 'roupa', null, 'Pet', '890 NC', 'Cash Shop', 890),
  ('Blue Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Leaf Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Mist Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Red Wanderers Scarf', 'roupa', null, 'Scarves', '710 NC', 'Cash Shop', 710),
  ('Sand Sensei Scarf', 'roupa', null, 'Scarves', '890 NC', 'Cash Shop', 890),
  ('Beige Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Black Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Blue Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Green Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Pink Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Purple Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Red Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('White Cozy Sweater', 'roupa', null, 'Sweaters', '710 NC', 'Cash Shop', 710),
  ('Blue Curse Mark Tattoo', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Blue', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Green', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Pink', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kanku Markings Red', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Blue', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Green', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Pink', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Kiba Markings Red', 'roupa', null, 'Tattoos & Markings', '440 NC', 'Cash Shop', 440),
  ('Agent Formal Pants', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Agent Formal Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Black Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Black Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Black High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Black Uzushi Pants', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Battle High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue Hashi Uniform', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Blue Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Blue Uzushi Pants', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Blue War Armor', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Dark Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Delinquent Uniform', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Flamezu Pants', 'roupa', null, 'Vests, Robes & Body', '440 NC', 'Cash Shop', 440),
  ('Forsaken Exile Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Fox Jacket', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Green Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Green High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Green Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Grey Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Izaku Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Light Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Magma War Armor', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Orange Shoes', 'roupa', null, 'Vests, Robes & Body', '440 NC', 'Cash Shop', 440),
  ('Orange Uzushi Pants', 'roupa', null, 'Vests, Robes & Body', '440 NC', 'Cash Shop', 440),
  ('Oto Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Pink Bow Kimono', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Pink Nurse Outfit', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Purple Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Purple High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Purple Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Reanimated Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Red Furred Armor', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Red Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Red High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Red Samurai Vest', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Sand Black Kimono', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Sand Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Sand Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Scorpion Jacket', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Shark Jacket', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Snowy Ghillie Suit', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Teal High-Collar Shirt', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('Training Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Two Tone Water Robes', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('White A-Ranker Pants', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('White A-Ranker Shirt', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('White Boxer Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('White Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710),
  ('White Izaku Robe', 'roupa', null, 'Vests, Robes & Body', '890 NC', 'Cash Shop', 890),
  ('Yellow Hashi Coat', 'roupa', null, 'Vests, Robes & Body', '710 NC', 'Cash Shop', 710)
on conflict (lower(name)) do update set
  type = 'roupa',
  clothing_slot = coalesce(items.clothing_slot, excluded.clothing_slot),
  clothing_price_text = coalesce(items.clothing_price_text, excluded.clothing_price_text),
  clothing_source = coalesce(items.clothing_source, excluded.clothing_source),
  price_nc = excluded.price_nc
where items.type = 'roupa' or items.type = 'item_mob';

update items set price_nc = v.price_nc
from (values
  ('Sand War Armor', 890),
  ('Red Forsaken Exile Robe', 890),
  ('Green Hashi Uniform', 890),
  ('Red Hashi Uniform', 890),
  ('Black Hashi Uniform', 890),
  ('Red Jira Vest', 890),
  ('Yellow Flash Shirt', 710),
  ('Pink Hyu Shirt', 710),
  ('Green Hyu Shirt', 710),
  ('Blue Hyu Shirt', 710),
  ('Dojo Shirt', 710),
  ('Dojo Pants', 440),
  ('Black Katahada Kimono', 890),
  ('Blue Katahada Kimono', 890),
  ('Sand Ragged Cape', 890),
  ('Justice Cape', 890),
  ('Black Hermit Cape', 890),
  ('White Snake Rope Belt', 890),
  ('Red Cursed Sakkat', 890),
  ('Black Cursed Sakkat', 890),
  ('Floppy Bunny Ears', 740),
  ('Black Oni Half Mask', 890),
  ('White Fox Mask', 890),
  ('Bandage Face Mask', 890),
  ('Black Cowl', 890),
  ('Burnt Bandage Head Wraps', 890),
  ('Summer Sunglasses', 890),
  ('Phantom Mask', 710),
  ('Black Blindfold', 440),
  ('White Blindfold', 440),
  ('Blood Medic Mask', 440),
  ('Blood Visor', 440),
  ('Sakura Visor', 440),
  ('Gray Wanderers Scarf', 710),
  ('Red Curse Mark Tattoo', 440),
  ('Rat Pal', 890)
) as v(name, price_nc)
where lower(items.name) = lower(v.name) and items.type = 'roupa' and items.price_nc is null;

insert into items (name, type, description, clothing_slot, clothing_price_text, clothing_source, price_nc, price_nc_notes) values
  ('Afro Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ahoge Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.7.9 (2025-07-30). Arte: Bell.'),
  ('Alchemist Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.9.9e (2025-10-12).'),
  ('Archangel Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ashura Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Assassin Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.5 (2026-01-20).'),
  ('Attack Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Azure Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bald Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Beast Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Big Spikes Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Blizzard Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bolt Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bone Marrow Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Bounty Hunter Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.13.4 (2026-07-03). Arte: Azuki.'),
  ('Bowl Cut Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Burn Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Buzz Cut Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cascade Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Center Parting Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Cherry Blossom Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cho Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cloudwalker Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.13.0 (2026-05-22).'),
  ('Clown Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.1d (2026-01-12). Arte: Genshin.'),
  ('Cornrows Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Cowboy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Deadlocks Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Dietz Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Double Cornrow Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Dragon Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.1d (2026-01-12). Arte: Fuze.'),
  ('Drifter Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Earth Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Erox Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Executioner Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.8 (2026-01-26).'),
  ('Faded Locks Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Fairytale Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Fantasy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Fencer Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Flame Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Flash Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Flat Top Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Four-tailed Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Fusion Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Great Puff Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Gun Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Haiku Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hanoka Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hanzai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hard Spikes Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Healer Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hermit Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hero Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Hozuki Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Indara Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Jiang Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.8.4 (2025-08-09).'),
  ('Jugo Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kaigaku Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kakuru Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kalinka Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kasumi Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Kawa Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('King Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Leafy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Long Bump Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Long Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Long Ponytail Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Long Twin Tail Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Madra Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Maeve Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.9.9e (2025-10-12).'),
  ('Mature Rebel Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('May Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Medium Bowl Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Medium Ponytail Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Messy Spiky Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Metro Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mighty Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mijikai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Minerva Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Model Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Mohawk Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Monk Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.9.7 (2025-09-25).'),
  ('Mullet Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Naji Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Naru Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Neat Long Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Nerdy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Neutron Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Nobura Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('One Side Shave Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ore Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Overlay Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Playboy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Pompadour Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Porcupine Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Prince Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Professor Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Punk Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.12.4 (2026-02-11). Arte: Fuze.'),
  ('Punk Star Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Raging Fire Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Rebel Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Rocker Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Ronin Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Royal Prince Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Saber Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update (2026-01-29).'),
  ('Salamander Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.8 (2026-01-26).'),
  ('Samurai Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sanemi Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Satan Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sato Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sharp Bangs Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Shaved Sides Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Shippu Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Dreads Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Messy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Pony Tail Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Short Ponytail Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Short Wavy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Shu Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Slickback Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Slugnir Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.8.6 (2025-08-15).'),
  ('Sly Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sniper Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sohei Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Soloist Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.8.6 (2025-08-15).'),
  ('Spellbound Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Highforehead Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Messy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Spiky Top Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Split Afro Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Star Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Sui Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Summers Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Swordsman Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Tachi Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Tear Drops Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Ghoul''s of Blizzard Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Guardian''s Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Lonely Vagabond Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Queen Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('The Wanderers Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Titan Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Tsunami Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.10.1 (2025-11-22).'),
  ('Twin Buns Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Twin Tails Hairstyle', 'roupa', null, 'Hairstyle', '260 NC', 'Cash Shop', 260, null),
  ('Viking Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Volume Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Wavy Curtain Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Wavy Messy Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, null),
  ('Wolfcut Premium Hairstyle', 'roupa', null, 'Hairstyle', '890 NC', 'Cash Shop', 890, 'Adicionado no Update v5.11.1d (2026-01-12). Arte: Kvaset.')
on conflict (lower(name)) do update set
  type = 'roupa',
  clothing_slot = 'Hairstyle',
  clothing_price_text = excluded.clothing_price_text,
  clothing_source = 'Cash Shop',
  price_nc = excluded.price_nc,
  price_nc_notes = excluded.price_nc_notes
where items.type = 'roupa' or items.type = 'item_mob';


-- ---------------------------------------------------------------
-- Skins & Eyes: 10 itens novos (type = 'consumivel')
-- ---------------------------------------------------------------
insert into items (name, type, description, price_nc) values
  ('Bandaged Skin', 'consumivel', 'A body skin wrapped in bandages.', 4400),
  ('Rikudo Skin', 'consumivel', 'A Sage-of-Six-Paths styled body skin.', 4400),
  ('Super Eye Color Changer', 'consumivel', 'Unlocks premium/animated eye color options.', 9400),
  ('Skin Color Dye', 'consumivel', 'Changes your character''s skin color.', 890),
  ('Mount Dye', 'consumivel', 'Changes the color of your mount.', 890),
  ('Eye Color Changer', 'consumivel', 'Changes your eye color.', 890),
  ('Eye Style Changer', 'consumivel', 'Changes your eye style.', 890),
  ('Muscle Skin', 'consumivel', 'A muscular body skin.', 890),
  ('Sexy No Jutsu', 'consumivel', 'A transformation body skin.', 890),
  ('Normal Skin', 'consumivel', 'Resets your character to the default skin.', 260)
on conflict (lower(name)) do update set
  type = 'consumivel',
  description = coalesce(items.description, excluded.description),
  price_nc = excluded.price_nc
where items.type = 'consumivel' or items.type = 'item_mob';

-- ---------------------------------------------------------------
-- Cash Shop Game Items: 10 itens novos (type = 'consumivel')
-- ---------------------------------------------------------------
insert into items (name, type, description, price_nc, price_nc_notes) values
  ('Royalty Collection Pack', 'consumivel', 'Royal Prince Hairstyle, Monkey Pal, Regal Shoulderguard, and 4x Palace Pillars.', 2700, 'Hold 1. Cannot be traded or destroyed.'),
  ('1000 Ninja Credit Chest', 'consumivel', 'Converts into 1000 Nin Credits (NC) when consumed.', 1000, 'Can be traded. Stack to 1000.'),
  ('Name Changer', 'consumivel', 'Renames your account to any available name, or one inactive 2+ years.', 890, 'Stack to 10. Cannot be traded or destroyed.'),
  ('Scroll of Stat Reset', 'consumivel', 'Resets your stats when used.', 890, 'Stack to 29k. Cannot be traded or destroyed.'),
  ('Inventory Expansion', 'consumivel', 'Unlocks 40 additional inventory slots permanently.', 890, 'Hold 1. Cannot be traded. (Premium)'),
  ('Guild Experience Booster Pack', 'consumivel', 'A random amount of tiered Scrolls of Guild Experience.', 620, 'Stack to 29k. Cannot be traded or destroyed.'),
  ('Premium Messenger Hawk 10 Pack', 'consumivel', 'Broadcast a message (up to 240 chars) to your village or the whole world.', 440, 'Hold 5.'),
  ('World Blessing (EXP Rate)', 'consumivel', 'Gives everyone online a 1.5x EXP rate; your name is shown to those benefiting.', 440, 'Stack to 29k.'),
  ('World Blessing (Drop Rate)', 'consumivel', 'Gives everyone online an increased item drop rate; your name is shown to those benefiting.', 440, 'Stack to 29k.'),
  ('New Ninja Free Gift', 'consumivel', 'A starter redemption pack to help new players.', null, '"Free" no card, não um preço em NC. Hold 1. Cannot be traded. (Unique)')
on conflict (lower(name)) do update set
  type = 'consumivel',
  description = coalesce(items.description, excluded.description),
  price_nc = excluded.price_nc,
  price_nc_notes = excluded.price_nc_notes
where items.type = 'consumivel' or items.type = 'item_mob';

-- ---------------------------------------------------------------
-- Furniture (só os 3 itens vendidos na Cash Shop): type = 'roupa',
-- clothing_slot = 'Furniture'
-- ---------------------------------------------------------------
insert into items (name, type, description, clothing_slot, clothing_price_text, clothing_source, price_nc) values
  ('Grand Piano', 'roupa', 'A large black grand piano that can be placed and rotated freely inside a player''s house.', 'Furniture', '440 NC', 'Cash Shop', 440),
  ('Palace Pillar', 'roupa', 'An ornate red-and-gold pillar that can be placed and rotated freely inside a player''s house. Four Palace Pillars are also included in the Royalty Collection Pack.', 'Furniture', '260 NC', 'Cash Shop', 260),
  ('White Neo Cash Register', 'roupa', 'Placed in a player''s house, it opens a personal shop with 20 shop slots that holds stocks of items and sells them to other players while you are offline. Also comes in Red, Purple, Pink and Teal recolors.', 'Furniture', '890 NC', 'Cash Shop', 890)
on conflict (lower(name)) do update set
  type = 'roupa',
  description = coalesce(items.description, excluded.description),
  clothing_slot = coalesce(items.clothing_slot, excluded.clothing_slot),
  clothing_price_text = coalesce(items.clothing_price_text, excluded.clothing_price_text),
  clothing_source = coalesce(items.clothing_source, excluded.clothing_source),
  price_nc = excluded.price_nc
where items.type = 'roupa' or items.type = 'item_mob';

-- ---------------------------------------------------------------
-- Seed: Anéis (migração 013, a partir do ninonline.fandom.com/wiki/Rings)
-- ---------------------------------------------------------------

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

drop trigger if exists items_set_updated_at on items;
create trigger items_set_updated_at
  before update on items
  for each row execute function set_updated_at();

drop trigger if exists mobs_set_updated_at on mobs;
create trigger mobs_set_updated_at
  before update on mobs
  for each row execute function set_updated_at();

drop trigger if exists npcs_set_updated_at on npcs;
create trigger npcs_set_updated_at
  before update on npcs
  for each row execute function set_updated_at();

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

-- ---------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------
-- Leitura pública (o site mostra pins/missões pra qualquer visitante).
-- Escrita só para usuários autenticados (login em /admin).
alter table arcos enable row level security;
alter table villages enable row level security;
alter table pins enable row level security;
alter table missions enable row level security;
alter table items enable row level security;
alter table mobs enable row level security;
alter table mob_drops enable row level security;
alter table npcs enable row level security;
alter table npc_shop_items enable row level security;
alter table masteries enable row level security;
alter table mastery_branches enable row level security;
alter table jutsus enable row level security;

drop policy if exists arcos_public_read on arcos;
create policy arcos_public_read on arcos for select using (true);

drop policy if exists villages_public_read on villages;
create policy villages_public_read on villages for select using (true);

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

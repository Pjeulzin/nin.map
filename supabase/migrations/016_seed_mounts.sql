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

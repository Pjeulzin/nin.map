-- Migration 008: sistema de builds (paridade com o NinForge)
--
-- Adiciona os campos que faltavam pra modelar armas e jutsus do jeito
-- que o jogo realmente funciona (baseado no ninforge.xyz): grupo de
-- arma, requisitos (nível + atributo), bônus da arma, raridade, e pro
-- jutsu: atributo/valor exigido, dano base e fator de escala. Também
-- semeia as 59 armas e ~90 jutsus reais do jogo (extraídos do próprio
-- ninforge.xyz) pra já vir populado.
--
-- Reaproveita a tabela `items` (tipo 'arma') e a tabela `jutsus` já
-- criadas na migração 007 — só estende com as colunas novas.

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

-- Chave estável em inglês pra cada maestria, igual ao NinForge (usada
-- pelo calculador de build pra bater com os dados importados).
alter table masteries add column if not exists external_key text;

update masteries set external_key = case slug
  when 'fogo' then 'Fire'
  when 'vento' then 'Wind'
  when 'raio' then 'Lightning'
  when 'terra' then 'Earth'
  when 'agua' then 'Water'
  when 'medicina' then 'Medical'
  when 'arma' then 'Weapon Master'
  when 'taijutsu' then 'Taijutsu'
end
where external_key is null;

create unique index if not exists masteries_external_key_unique_idx on masteries (external_key);

-- Requisito de atributo + dano base/escala do jutsu, pro calculador de
-- build. `stat_req_stat` usa as siglas do jogo: str/for/int/agi/cha.
alter table jutsus add column if not exists stat_req_stat text;
alter table jutsus add column if not exists stat_req_value integer;
alter table jutsus add column if not exists base_damage integer;
alter table jutsus add column if not exists scaling numeric(4,2);

create unique index if not exists jutsus_mastery_name_unique_idx on jutsus (mastery_id, name);

-- ---------------------------------------------------------------
-- Armas (59 modelos reais do jogo, por categoria)
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

-- ---------------------------------------------------------------
-- Jutsus (todos os jutsus de todas as maestrias, com requisito de
-- atributo, dano base e fator de escala)
-- ---------------------------------------------------------------

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

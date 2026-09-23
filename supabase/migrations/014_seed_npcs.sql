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

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

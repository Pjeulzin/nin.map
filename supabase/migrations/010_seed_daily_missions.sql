-- Cadastro das Missões Diárias (Daily Missions) usando
-- ninonline.fandom.com/wiki/Missions como fonte, extraído da API do
-- MediaWiki (infobox de cada missão + seção "Objectives").
--
-- Escopo: só as ~63 missões da seção "Daily Missions" (D/C/B/A/S rank)
-- do wiki — não as questlines de storyline (Bandit Questline, Land of
-- Waves, Land of Spirits etc.), que ficam de fora por enquanto.
--
-- O próprio wiki documenta lacunas nesses dados (campos "?", "not
-- recorded"): quando isso acontece aqui, xp/ryo ficam 0 e level_min/
-- level_max ficam null, e o texto da wiki (quando existir) vai pra
-- description. Ajuste os valores no admin (admin/missions.html) se
-- tiver dados mais precisos (ex: captura de tela do card em jogo).
--
-- "Mission Assignments (Leaf/Sand/Mist)" são a mesma missão em 3
-- variantes por vila — por isso viram 3 linhas com o mesmo nome e
-- village_id diferente (index composto abaixo permite isso).

-- Índice único que trata "mesma missão, vilas diferentes" como linhas
-- distintas, mas evita duplicar a mesma missão+vila se essa migração
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

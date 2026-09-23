# Nin.Map

Mapa interativo do mundo de **Nin Online**, feito com [Leaflet](https://leafletjs.com/).

## Como funciona

O mapa usa o modo `L.CRS.Simple` do Leaflet, que trata a imagem do mapa como
um plano de coordenadas (x, y) ao invés de coordenadas geográficas — é a
forma padrão de exibir mapas de jogos (não é o mundo real).

## Estrutura

```
site/
├── index.html                  # mapa principal (com seletor de arco e vila)
├── missions.html                # listagem pública de missões
├── mobs.html                    # listagem pública de mobs
├── mob-detail.html               # ficha detalhada de um mob (mais info que o card da listagem)
├── npcs.html                    # listagem pública de NPCs
├── npc-detail.html               # ficha detalhada de um NPC
├── items.html                   # catálogo público de itens
├── masteries.html                # listagem pública de maestrias
├── mastery-detail.html           # ficha detalhada de uma maestria (+ lista de jutsus)
├── jutsus.html                   # listagem pública de jutsus
├── builds.html                   # calculador de build (personagem completo)
├── css/style.css                 # estilos (site + admin)
├── js/config.js                  # lista de arcos e de vilas
├── js/village.js                 # vila escolhida pelo jogador (persistência)
├── js/server.js                  # servidor escolhido (Toad/Hawk) — define o idioma padrão
├── js/i18n.js                    # textos da interface em PT/EN
├── js/chrome.js                  # monta os seletores de servidor/idioma no topo de cada página
├── js/nav.js                     # arrastar/minimizar o painel flutuante
├── js/map.js                     # lógica do mapa (Leaflet + pins do Supabase)
├── js/missions.js                # lógica da listagem de missões
├── js/missions-shared.js         # helpers de formatação (nível, objetivos)
├── js/mobs.js                    # lógica da listagem de mobs
├── js/mob-detail.js              # lógica da ficha detalhada de mob
├── js/npcs.js                    # lógica da listagem de NPCs
├── js/npc-detail.js              # lógica da ficha detalhada de NPC
├── js/npcs-shared.js             # helpers de formatação (papel, localização, loja)
├── js/items.js                   # lógica do catálogo de itens
├── js/mobs-shared.js             # helpers de formatação (categoria, dano, drops, categoria de arma)
├── js/masteries.js               # lógica da listagem de maestrias
├── js/mastery-detail.js          # lógica da ficha detalhada de maestria
├── js/masteries-shared.js        # helpers de formatação (ramificações)
├── js/jutsus.js                  # lógica da listagem de jutsus
├── js/jutsus-shared.js           # helpers de formatação (chakra, cooldown, nível)
├── js/builds.js                  # calculador de build (fórmulas de status, jutsus, anéis, salvar/compartilhar)
├── js/storage-upload.js          # upload/remoção de ícone no Supabase Storage (compartilhado)
├── js/supabase-config.js         # URL + anon key do seu projeto Supabase
├── js/supabaseClient.js          # cliente Supabase compartilhado
├── assets/map-arco*.jpg          # imagem de cada arco (placeholders por enquanto)
├── data/locations.example.json   # exemplo de formato para marcadores
├── supabase/schema.sql           # schema do banco (tabelas, RLS)
├── supabase/migrations/          # migrações incrementais (rode se já tinha o schema antigo)
│   ├── 007_add_masteries_weapons_jutsus.sql  # maestrias, ramificações, jutsus e extensão de armas
│   ├── 008_add_build_system_data.sql         # grupo/requisitos/bônus de arma, requisito de jutsu, + dados reais do jogo
│   ├── 009_add_detail_fields.sql             # descrição/imagem/habilidades de mob, imagem de NPC, "como jogar" de maestria
│   ├── 010_seed_daily_missions.sql           # semeia as Missões Diárias a partir do ninonline.fandom.com/wiki/Missions
│   ├── 011_seed_mobs.sql                     # semeia os 145 mobs (com drops) a partir do ninonline.fandom.com/wiki/Category:Mob
│   ├── 012_seed_proficiencies.sql            # cadastra as 10 Proficiências (coleta/crafting) + receitas de Tecelagem e Culinária
│   ├── 013_seed_rings.sql                    # cadastra os 41 Anéis (Rings) a partir do ninonline.fandom.com/wiki/Rings
│   ├── 014_seed_npcs.sql                     # cadastra 66 NPCs a partir do ninonline.fandom.com/wiki/Category:NPC
│   ├── 015_seed_clothes.sql                  # cadastra 306 Clothes (roupas/cosméticos) a partir do ninonline.fandom.com/wiki/Category:Clothing
│   ├── 016_seed_mounts.sql                   # cria a tabela `mounts` e cadastra as 13 Montarias a partir do ninonline.fandom.com/wiki/Category:Mounts
│   ├── 017_seed_more_missions.sql            # cadastra 74 missões de storyline/questline que ficaram de fora da migração 010
│   ├── 018_seed_organizations_and_restricted_items.sql  # cria a tabela `organizations` e cadastra as 8 Organizações + 10 itens restritos por cargo
│   └── 019_seed_cash_shop_items.sql          # cadastra 353 itens da Cash Shop (Outfits, Hairstyles, Skins & Eyes, Game Items, Furniture)
└── admin/                        # área de cadastro (login + CRUD)
    ├── index.html                 # login
    ├── pins.html                  # cadastro de pins (clique no mapa)
    ├── missions.html               # cadastro de missões
    ├── mobs.html                   # cadastro de mobs (com drops)
    ├── npcs.html                   # cadastro de NPCs (papéis + itens à venda)
    ├── items.html                  # cadastro de itens (armas incluídas)
    ├── masteries.html               # cadastro de maestrias (+ ramificações)
    ├── jutsus.html                  # cadastro de jutsus
    └── js/                         # auth.js, login.js, *-admin.js
```

## Navegação (painel flutuante)

As páginas públicas (Mapa, Missões, Mobs, NPCs e Itens) não têm mais
barra fixa no topo nem no rodapé. Em vez disso, tudo — navegação
entre páginas, servidor/idioma, e os filtros/busca de cada página —
fica dentro de um **painel flutuante** (`#ninmap-panel`) que fica por
cima do conteúdo:

- **Arrastar**: clique e segure no cabeçalho do painel (onde tem o
  ícone ⠿ e o nome "Nin.Map") e arraste pra qualquer lugar da tela.
- **Minimizar**: o botão "–" no canto do cabeçalho encolhe o painel
  pra só a barra de cima; clique de novo (agora "▢") pra expandir.
- A posição e o estado (minimizado ou não) ficam salvos no navegador
  (`localStorage`), então continuam do jeito que você deixou ao trocar
  de página — a lógica de arrastar/minimizar fica em `js/nav.js`.

Dentro do painel, de cima pra baixo: os links de navegação (🗺️ Mapa,
📜 Missões, 👹 Mobs, 🧙 NPCs, 🎒 Itens, 🌀 Maestrias, 🥷 Jutsus, 🛠️
Builds — o da página atual fica destacado em verde), o seletor de servidor/idioma, os filtros/busca
específicos daquela página, e por último o acesso ao `/admin`
(ícone ⚙️, separado visualmente por ser uma ferramenta sua, não dos
jogadores) e o crédito "Criado por Pjeul".

Pra adicionar uma nova seção ao menu (ex: uma futura página de
Eventos), copie um dos blocos `<a class="float-panel__link">` dentro
de `<nav class="float-panel__nav">` em cada página pública, e marque
o da página atual com a classe extra `float-panel__link--active`. Pra
adicionar um filtro novo numa página, coloque o campo dentro de
`<div class="float-panel__filters">` — os estilos já deixam
selects/inputs/botões com 100% da largura do painel.

## Arcos (mapas instanciados)

O site tem um seletor no topo para trocar entre os arcos do jogo — hoje:
Arco 20, Arco 30, Arco 50 e Arco 60. Cada arco é um mapa independente,
com sua própria imagem e seus próprios marcadores.

A escolha do arco fica salva (no navegador) e também na URL, ex:
`index.html?arco=30` — então dá pra compartilhar um link já apontando
pro arco certo.

## Vilas (Névoa, Folha, Areia, Renegados)

O site tem um seletor de vila na tela inicial (junto do seletor de
arco). A escolha fica salva no navegador e também na URL (ex:
`index.html?vila=neblina`), e é reaproveitada na página de missões
como filtro inicial — dá pra trocar por lá também, e a escolha fica
sincronizada nas duas páginas.

### Por que isso importa pras missões

Algumas missões (principalmente as diárias) têm o mesmo nome e
recompensa em qualquer vila, mas pedem itens diferentes pra coletar.
Exemplo real: **Medicine Supplies I** (sempre 40 cocoons + 20 de um
segundo item, nível 3 ao 7):

| Vila | 2º item do objetivo |
|---|---|
| Névoa | Dragonfly Wing |
| Areia | Cauda de Escorpião |
| Folha | Spider Egg |

Isso é modelado como **três linhas separadas** na tabela `missions`:
mesmo `name`, mesmo `rank`/xp/ryo/nível, mas `village_id` e
`objectives` diferentes. Uma missão sem vila definida (`village_id`
vazio) é tratada como válida pra qualquer vila.

No cadastro (`admin/missions.html`), depois de preencher a primeira
variante, edite os objetivos e troque a vila no formulário e clique em
**"Duplicar para outra vila"** em vez de "Salvar" — isso cria uma nova
missão com os dados atuais do formulário, sem alterar a que você abriu
pra editar. Repita pra cada vila.

Na página pública de missões, o filtro de vila mostra a missão da vila
selecionada **e** as que não têm vila definida (globais).

> Os pins do mapa ainda não são filtrados por vila — isso fica pra uma
> próxima etapa (marcar no mapa onde/o que caçar pra cada objetivo,
> por vila).

### Adicionar, remover ou editar um arco

Edite `js/config.js`. Cada arco é um item do array `ARCOS`:

```js
{
  id: "30",              // usado na URL (?arco=30) — não repita ids
  label: "Arco 30",       // texto mostrado no seletor
  image: "assets/map-arco30.jpg",
  width: 2048,            // largura real da imagem, em pixels
  height: 2048,           // altura real da imagem, em pixels
  locations: [],          // marcadores desse arco (veja abaixo)
}
```

## Servidor e idioma (Toad/NA em inglês, Hawk/BR em português)

Todo canto do site pública tem, no topo, um seletor de **servidor**
(Toad Server ou Hawk Server) e um botão de **idioma** (🇧🇷 PT / 🇺🇸 EN).

- Escolher o servidor já troca o idioma da interface automaticamente:
  Toad → inglês, Hawk → português. Isso fica salvo no navegador e
  também na URL (`?server=toad`).
- Depois disso, dá pra trocar o idioma manualmente no botão PT/EN sem
  mexer no servidor escolhido — as duas escolhas ficam independentes
  uma vez que você troca o idioma na mão.

**O que é traduzido:** só a interface do site — menus, filtros,
rótulos ("Nível", "Dano", "Objetivo" etc.), mensagens de carregamento/
erro, e os nomes de categoria/tipo (rank de missão, categoria de mob,
tipo de item). Os nomes e descrições que você cadastra no admin
(nome da missão, do mob, do item, descrições) **não são traduzidos** —
ficam exatamente como você digitou, pra não precisar cadastrar tudo
duas vezes. A área de admin (`/admin`) também não é traduzida — ela é
uma ferramenta sua, não dos jogadores, e continua sempre em português.

### Adicionar um novo idioma ou editar um texto

Os textos ficam todos em `js/i18n.js`, num objeto `STRINGS` com uma
chave `pt` e uma `en`. Pra corrigir uma tradução, edite o texto ali.
Pra outro idioma, duplique um dos blocos com as mesmas chaves e ajuste
`js/server.js` (campo `lang` de cada servidor) e o toggle em
`js/chrome.js` se quiser mais de duas opções no botão.

## Trocar a imagem de um arco pela real

1. Coloque a imagem completa do mapa desse arco em `assets/` (pode usar
   o nome que quiser, só aponte em `image` no `js/config.js`).
2. Ajuste `width` e `height` desse arco em `js/config.js` para o tamanho
   real da imagem em pixels.
3. Recarregue a página — o Leaflet ajusta o zoom automaticamente.

## Adicionar marcadores (cidades, dungeons, NPCs, etc.)

Edite o array `locations` do arco correspondente em `js/config.js`.
Cada item precisa de:

```js
{ name: "Nome do local", type: "cidade", x: 1024, y: 1024, description: "..." }
```

`x` e `y` são coordenadas em pixels na imagem do mapa (origem no canto
inferior esquerdo). Tipos suportados por padrão: `cidade`, `dungeon`,
`npc`, `recurso` (dá pra adicionar mais editando `markerIcons` em
`js/map.js`).

## Rodar localmente

Como o navegador bloqueia `fetch`/imagens locais em alguns casos com
`file://`, o mais simples é subir um servidor local, por exemplo:

```bash
cd site
python -m http.server 8000
```

E abrir `http://localhost:8000`.

## Integração com Supabase (pins e missões)

Pins e missões são cadastrados em `/admin` e ficam guardados no
Supabase; o site (mapa e página de missões) lê de lá.

### 1. Criar o projeto e as tabelas

1. Crie uma conta e um projeto em [supabase.com](https://supabase.com).
2. No painel do projeto, abra **SQL Editor**, cole o conteúdo de
   `supabase/schema.sql` e rode. Isso cria as tabelas `arcos`, `villages`,
   `pins`, `missions`, `items`, `mobs`, `mob_drops`, `npcs`,
   `npc_shop_items`, o bucket de storage `item-icons` (pra ícone dos
   itens) e as políticas de segurança (RLS). Se você já
   tinha rodado uma versão anterior do
   schema, rode também as migrações que faltam, em ordem, na pasta
   `supabase/migrations/` (cada uma diz no comentário se pode ser
   ignorada quando o schema já foi rodado do zero).
3. Em **Project Settings → API**, copie a **Project URL** e a
   **anon public key**.
4. Cole os dois valores em `js/supabase-config.js`:

   ```js
   export const SUPABASE_URL = "https://xxxxx.supabase.co";
   export const SUPABASE_ANON_KEY = "eyJhbGciOi...";
   ```

   A anon key é pública por design (fica exposta no navegador) — quem
   protege os dados são as políticas de RLS: qualquer pessoa pode
   **ler** pins/missões, mas só usuários **autenticados** conseguem
   criar, editar ou excluir.

### 2. Criar seu usuário de admin

Em **Authentication → Users → Add user**, crie um usuário com e-mail e
senha (pode ser o seu). É esse login que dá acesso a `/admin`.

### 3. Cadastrar pins e missões

- `admin/pins.html` — escolha o arco, clique no mapa para marcar a
  posição (X/Y são preenchidos automaticamente), preencha nome/tipo/
  descrição e salve. A tabela ao lado lista os pins do arco selecionado,
  com opção de editar (clicando no pin ou na linha) e excluir.
- `admin/missions.html` — cadastra nome, descrição, tipo da missão
  (global, exclusiva de arco, evento ou diária), rank (S, A, B, C ou D),
  vila (opcional — veja "Vilas" abaixo), XP, ryo, nível necessário
  (exato, mínimo, até um nível, ou intervalo) e os objetivos (lista de
  item + quantidade, com botão para adicionar mais itens).

Na página pública de missões (`missions.html`) dá pra filtrar por
vila, tipo, arco e rank, e cada missão mostra um selo colorido com a
letra do rank.

Enquanto `js/supabase-config.js` ainda estiver com os valores de
placeholder, o mapa cai de volta nos `locations` de exemplo do
`js/config.js`, e a página de missões avisa que o Supabase não foi
configurado — nada quebra, mas nada é salvo de verdade até você
preencher as credenciais.

### Tipos de missão suportados

| Tipo | Quando usar |
|---|---|
| `global` | Disponível em qualquer arco |
| `arco` | Exclusiva de um arco (exige selecionar o arco) |
| `evento` | Missão de evento temporário |
| `diaria` | Diária, normalmente feita no mapa global |

Missões de RP (passadas por outro jogador) ficam de fora por enquanto,
como combinado.

### Missões Diárias pré-cadastradas (migração 010)

A migração `supabase/migrations/010_seed_daily_missions.sql` (espelhada
no `schema.sql`) já semeia as ~63 **Missões Diárias** listadas em
[ninonline.fandom.com/wiki/Missions](https://ninonline.fandom.com/wiki/Missions)
(seções D/C/B/A/S-Rank Missions), extraídas direto da API do MediaWiki
(infobox + seção "Objectives" de cada página de missão). Todas entram
com `mission_type = 'diaria'`.

Escopo: só as diárias. As questlines de storyline completas (Bandit
Questline, Land of Waves, Land of Spirits etc.) e as missões dadas por
NPC específico ficam de fora por enquanto — são bem mais páginas pra
processar e podem entrar depois se você pedir.

O próprio wiki documenta lacunas nesses dados — vários "?", "not
recorded" nas tabelas de nível/XP/Ryo. Onde isso acontece, o XP/Ryo
ficam `0` e o nível fica em branco aqui, e o texto que o wiki tem
(mesmo incompleto) vai pro campo `description` da missão, pra você
completar depois com dados mais exatos (ex: print do card da missão em
jogo). Quatro delas ("Fox Hunting", "Antidotes Creation", "Giant Ant
Infestation", "Medicine Supplies III") nem têm página própria no wiki
ainda — entraram só com rank e uma nota.

"Mission Assignments" tem uma variante por vila (Leaf/Sand/Mist), e
elas entram como 3 linhas com o mesmo nome e `village_id` diferente —
por isso a seed usa um índice único em `(name, coalesce(village_id, ''))`
em vez de só `name`, pra rodar de novo sem duplicar.

Onde o wiki descreve o objetivo como "matar N de X" (ex: "Kill 80
Larvae"), isso também populou o campo `objectives` (`{item, quantity}`)
igual ao formato que o admin já usa. Objetivos mais narrativos (fuga,
escolta, infiltração) ficaram só na `description`, porque não são um
"item + quantidade" de verdade.

### Missões de storyline/questline pré-cadastradas (migração 017)

A migração `supabase/migrations/017_seed_more_missions.sql` (espelhada
no `schema.sql`) cobre o que a migração 010 deixou de fora: as
questlines de storyline (Land of Spirits, Land of Iron/Rebel Camp,
Land of Toads, Takumi arc, Kinsen Mobsters) e missões de NPC específico
de [Category:Missions](https://ninonline.fandom.com/wiki/Category:Missions)
(141 páginas na categoria, 72 ainda não cadastradas). Entraram **74
linhas**, a partir de 70 páginas:

- **Fora de escopo (2 páginas):** "Sea Mini Questlines" — a própria
  página se marca como depreciada em 15/09/2026 (update v5.13.6.9), as
  missões antigas foram removidas do jogo e substituídas por uma
  questline nova que a wiki ainda não documenta sob título próprio.
  "Yuu Mini Questline" — não é uma missão em si, é um walkthrough que
  complementa "Hidden Tomb" (a missão de verdade já está cadastrada).
- **Páginas "hub" viraram várias linhas (3 páginas → 7 linhas):** as
  três páginas do Land of Toads (introdução de Hitsutomo, cadeia de
  coleta de Hoshitomo, cadeia de caça de Momotomo) documentam mais de
  uma missão cada — cada sub-missão (Land Of Toads I/II; Obtain
  Talons/Feathers/Raccoon Tails; Natural Enemies I/II) virou sua
  própria linha.
- **Rank "Main":** 8 missões de storyline usam "Main" na wiki, fora da
  escala S/A/B/C/D do enum `mission_rank` — entraram como `rank = 'S'`
  com uma nota explícita no `description` avisando que o rank real da
  wiki é "Main". O mesmo vale pra qualquer rank/nível/recompensa que a
  wiki não documenta ("Information needed") ou documenta fora do
  padrão: vira nota no `description` em vez de um chute.
- **Vila:** as 3 missões de "achar os selos da vila" (Cleanse The
  Temple, Hidden in the Desert, Darker Places) entraram com
  `village_id` da vila correspondente (Névoa/Areia/Folha). As demais
  ficaram com `village_id` null.
- **Arco:** `arco_id` ficou null pra todas — os 4 arcos cadastrados
  hoje (20/30/50/60) são as instâncias do mapa principal, e essas
  missões acontecem em regiões nomeadas à parte (Land of Iron, Land of
  Spirits, Land of Toads, Kinsen Quarters...) sem correspondência 1:1
  documentada com esses IDs ainda.
- **Diária:** só "Hornet Infestation" entrou como
  `mission_type = 'diaria'` — é a única deste lote que a wiki chama de
  "repeatable daily mission". As outras 73 entraram como `'global'`.
- **Objetivos:** o campo `objectives` ficou vazio pra todas as linhas
  deste lote — a maioria é narrativa (fale com X, escolte, explore,
  resolva um enigma) mesmo quando tem contagem de kill embutida; o
  texto completo dos objetivos (quando a wiki documenta) foi pro
  `description`, no mesmo espírito da migração 010.
- **XP/Ryo:** extraídos só quando a wiki dá um número limpo (ex:
  "220,600 EXP + 50 Ryo"). Recompensa em item, título, cupom, ou texto
  livre vira nota no `description` em vez de um valor inventado.

## Mobs e itens

Duas tabelas novas, relacionadas entre si:

- **Itens** (`admin/items.html`) — catálogo simples: nome, tipo (anel,
  arma, roupa, consumível ou item de mob) e descrição. Cadastre o item
  primeiro — ele só aparece na lista de drops de um mob depois de
  existir aqui.
- **Mobs** (`admin/mobs.html`) — categoria (boss, enfurecido ou
  regular), nível, localização, vida (HP), dano (mínimo/máximo), tipo
  de combate (passivo ou agressivo), XP de recompensa e uma lista de
  drops (item + quantidade mín/máx + % de chance, opcional).

### Localização do mob

Igual foi combinado: por enquanto a localização é só texto livre
(campo "Descrição da localização") + o arco onde ele fica. Quando você
cadastrar o pin desse mob no mapa (`admin/pins.html`), volte no mob e
selecione o pin no campo "Pin no mapa" — a partir daí a localização
mostrada passa a ser o nome do pin. O campo já existe no banco
(`mobs.pin_id`), só falta ligar os dois quando os pins específicos de
mob existirem.

### Cadastrando os drops de um mob

No formulário de mob, a seção "Drops" deixa adicionar quantas linhas
quiser: escolha o item (já cadastrado em Itens), quantidade mínima e
máxima, e opcionalmente a % de chance de drop. Ao salvar, os drops
antigos desse mob são substituídos pelos que estão no formulário —
então pra remover um drop, é só apagar a linha antes de salvar.

Na página pública de mobs (`mobs.html`) dá pra filtrar por arco,
categoria e tipo de combate, e cada card mostra vida, dano, XP e os
drops formatados. A página de itens (`items.html`) lista o catálogo
completo com filtro por tipo, tem um campo de pesquisa por nome/
descrição que filtra em tempo real, e mostra quais mobs dropam cada
item.

### Imagem (ícone) do item

No formulário de item (`admin/items.html`) dá pra fazer upload de uma
imagem — fica melhor em ícones quadrados, estilo item de inventário de
jogo. A imagem é enviada pro **Supabase Storage**, num bucket público
chamado `item-icons` (criado automaticamente ao rodar o
`schema.sql`/migração 006 — veja "Criar o projeto e as tabelas"
acima). Trocar a imagem de um item apaga a anterior do storage;
"Remover imagem" limpa o campo sem precisar apagar o item.

A imagem aparece dentro de um "slot" com moldura (a mesma classe CSS
`.item-icon-frame`, em `css/style.css`) tanto na tabela do admin
quanto na página pública de itens. Item sem imagem cadastrada mostra
o slot vazio, sem quebrar nada.

### Página de detalhes do mob (`mob-detail.html`)

Cada card de mob em `mobs.html` agora é um link pro nome, que leva pra
`mob-detail.html?id=<uuid>` — uma "ficha" mais completa, no espírito
das páginas de mob do **ninonline.fandom.com/wiki** (ex:
`/wiki/Bear`, `/wiki/Chei`): imagem grande, nível/HP/dano/XP em
destaque, texto de descrição/lore, lista de **habilidades especiais**
nomeadas e a tabela de drops. Três campos novos em `mobs` sustentam
isso (migração 009):

- `description` — texto livre (lore, comportamento, dicas de combate).
- `image_url` — mesmo padrão de upload dos itens/maestrias/jutsus
  (bucket `item-icons`, campo "Imagem" no formulário de mob).
- `special_abilities` — lista de nomes (uma por linha no admin), ex.:
  "Mountain Crash", "Body Flicker (21 tiles)".

Nenhum desses três é obrigatório — mob sem nada cadastrado nesses
campos ainda funciona, só mostra menos detalhe na ficha.

### Mobs pré-cadastrados (migração 011)

A migração `supabase/migrations/011_seed_mobs.sql` (espelhada no
`schema.sql`) semeia **todos os 145 mobs** listados em
[ninonline.fandom.com/wiki/Category:Mob](https://ninonline.fandom.com/wiki/Category:Mob),
incluindo os drops de cada um, extraídos direto da API do MediaWiki
(infobox `{{Infobox/Monster|...}}` de cada página e, quando existe, a
tabela "Loot List", mais precisa que o campo de texto livre de drops).

Os itens de drop que ainda não existiam no catálogo foram criados
automaticamente como `type = 'item_mob'` — são **148 itens novos**, sem
descrição nem imagem ainda (preencha depois em `admin/items.html`). A
seed usa `on conflict (lower(name)) do nothing` pros itens, então rodar
a migração de novo nunca sobrescreve um item que você já editou
manualmente (nome, descrição, imagem ou até um `type` diferente que
você tenha corrigido).

Classificação em `category`:

- **boss** — mobs listados nas categorias Category:BOSS/Category:Boss
  da wiki, ou cujo campo `type` do infobox contém a palavra "Boss"
  (ex.: "Yokai (Boss)" pra Ongaku, Kikkumaru, Jirou). 45 mobs.
- **enfurecido** — nome começa com "Angry", "Enraged" ou "Mad" (não
  existe categoria própria pra isso na wiki, foi heurística por nome).
  6 mobs.
- **regular** — todo o resto. 94 mobs.

Lacunas de dados: cerca de 26 mobs não têm infobox completo na própria
wiki (páginas-stub, principalmente do tipo "Elite" e alguns marcados
"Not recorded"/"Information needed"). Como `level` e `hp` são colunas
`not null`, esses mobs entraram com o default da coluna (nível 1, HP
1) em vez de ficar em branco — corrija manualmente no admin quando o
valor certo for descoberto/confirmado em jogo.

Taxas de drop (`drop_rate`): quando a página tinha uma "Loot List"
estruturada, o percentual veio direto dela; quando só havia o campo de
texto livre (ex.: "Common", "Rare", "<5%"), foi convertido por uma
tabela aproximada (Common=50%, Uncommon=20%, Rare=5%, "<1%"=0.5%,
"<5%"=3%); quando não dava pra inferir nada, `drop_rate` ficou em
branco (null) — o mob continua listando o drop, só sem % definida.

Imagens de mob (`image_url`) ficaram propositalmente em branco, como
combinado — o upload é manual, feito depois por você no admin.

## Proficiências (coleta e crafting)

Três tabelas novas, a partir de
[ninonline.fandom.com/wiki/Proficiencies](https://ninonline.fandom.com/wiki/Proficiencies)
(migração `supabase/migrations/012_seed_proficiencies.sql`, espelhada no
`schema.sql`):

- **`proficiencies`** — as 10 profissões de coleta/crafting do jogo (bem
  diferente das 8 maestrias de combate da tabela `masteries` — fogo,
  vento, taijutsu etc. — que já existiam). São 4 de coleta (Mineração,
  Corte de Madeira, Pesca, Forrageamento) e 6 de crafting (Forjaria,
  Tecelagem, Carpintaria, Culinária, Transmutação, Fuinjutsu). Cada uma
  vai até o nível 500, com 1% de bônus de sucesso a cada 10 níveis
  (50% no cap).
- **`proficiency_recipes`** — as receitas de cada profissão: nome,
  nível pra desbloquear, item produzido (`output_item_id`), se precisa
  de bancada de trabalho, taxa de sucesso base (quando registrada),
  tempo de craft e o efeito do item (pra comidas com buff).
- **`proficiency_recipe_materials`** — os ingredientes de cada receita
  (item + quantidade).

Escopo desta migração: as 10 profissões + as receitas documentadas na
wiki. Só **Tecelagem** e **Culinária** têm página própria com lista de
receitas — as outras 8 (incluindo Forjaria, que o hub da wiki lista mas
cujo link hoje só redireciona pra um resumo genérico) ainda não têm
receita nenhuma publicada, só a descrição geral do que fazem.

**Tecelagem**: 24 receitas (17 com nível de desbloqueio conhecido + 7
que só vêm de drop de mob específico, sem nível publicado). A wiki não
documenta os materiais dessas receitas, só o item final — por isso elas
não têm linhas em `proficiency_recipe_materials`.

**Culinária**: 21 receitas, essas com ingredientes completos (a página
foi inteiramente redocumentada em 16 de agosto de 2026). A taxa de
sucesso base só é confirmada pra Rice Ball (90%, lida no skill 0);
Fried Egg tem uma taxa aproximada (~50%); as outras 19 receitas não têm
taxa nem tempo de craft registrados ainda.

Itens novos referenciados pelas receitas (ingredientes e produtos que
ainda não existiam no catálogo) foram criados com `type = 'consumivel'`
— o enum `item_type` atual (anel/arma/roupa/consumivel/item_mob) não
tem uma categoria própria pra "ingrediente de crafting". Se quiser mais
precisão, ajuste manualmente no Admin o tipo dos itens vestíveis
craftados pela Tecelagem (chapéus, botas, calças, cachecóis, máscaras,
capas) pra `roupa`. Igual nas migrações anteriores, o
`on conflict do nothing` garante que reexecutar essa migração nunca
sobrescreve um item que você já editou manualmente.

## Anéis (Rings)

A migração `supabase/migrations/013_seed_rings.sql` (espelhada no
`schema.sql`) cadastra os **41 anéis** documentados em
[ninonline.fandom.com/wiki/Rings](https://ninonline.fandom.com/wiki/Rings),
como itens `type = 'anel'` na tabela `items` já existente. Anéis são
cosmeticamente invisíveis no jogo — só dão bônus de atributo, sem mudar
a aparência do personagem.

Como o mesmo anel nomeado pode dropar em mais de uma raridade (às
vezes até duas variantes "Uncommon" diferentes com o mesmo nome), cada
raridade documentada vira um objeto dentro de um array `jsonb` na nova
coluna `ring_variants` — em vez de uma coluna fixa de bônus. A migração
também adiciona `ring_family` (nome da família, ex. "Qi Ring", "Zodiac"
— null pros 4 avulsos sem família), `ring_level_required` e
`ring_notes` (lacunas de dados, em português) na tabela `items`.

Formato de cada variante em `ring_variants`:

```json
{"rarity": "Rare", "stats": {"Chakra": 2}, "percent": {"Chakra Steal": "2%"}}
```

`costs` aparece só nos 12 anéis do Zodíaco (débito de atributo que vem
junto do bônus) e `percent` só nos 3 anéis de crit/steal.

**Famílias cadastradas:** Qi Ring (5), Chakra Vein Band (3), Spirit
Rend Band (3), Bedrock Band (5), Agate Ring (4), Stargazer Ring (5),
Zodiac (12, incluindo o Ring of the Jade Dragon, que não tem página
própria na wiki mas tem os dados completos no quadro-resumo da página
Rings) e 4 avulsos sem família (Deathmarch Band, Eclipsed Crystal
Ring, Shark Tooth Ring, Moontide Pearl Ring).

**Fora do escopo:** o Kuronami Ring, que a própria wiki arquiva fora
da Category:Rings por ser restrito a membros da organização
Neo-Akatsuki (drop ao morrer, não faz parte do sistema normal de drop
de anéis).

**Lacunas de dados** (documentadas por anel em `ring_notes`): faltam
algumas variantes de raridade em várias famílias (ex. Rare de
Granite/Basalt/Slate Bedrock Band, Common/Uncommon do Iron Spirit Rend
Band), uma quinta cor da família Agate Ring, a variante +7 do Sapphire
Stargazer Ring, e as variantes mais fortes ("4%"/"6%") dos 3 anéis de
crit/steal — só a mais fraca documentada está cadastrada.

A família **Qi Ring** tem uma inconsistência da própria wiki entre
editores: a página do Sapphire Qi Ring descreve uma tabela de família
diferente da tabela genérica usada nas páginas de Amber/Amethyst/
Ruby/Topaz. Mantivemos os dados como cada página individual documenta,
sem tentar reconciliar — ver a nota do Sapphire Qi Ring.

As outras 4 categorias do hub [Items](https://ninonline.fandom.com/wiki/Items)
da wiki (Weapons — já cadastrado na migração 008 —, Clothes, Consumable
e Other items) ficam de fora por enquanto; Clothes sozinha tem 335
itens na categoria, então acaba sendo o próximo pedaço grande se você
quiser continuar depois.

## NPCs

NPCs (`admin/npcs.html`) são cadastrados com nome, um ou mais
**papéis** (Vendedor, Concede missão, Parte de missão, Outro —
marcados por checkbox, um NPC pode acumular vários ao mesmo tempo),
descrição, localização (mesmo padrão dos mobs: arco + pin opcional +
descrição em texto livre) e, quando ele vende algo, uma lista de
"Itens que vende" (item já cadastrado em Itens, preço em ryo e
estoque — deixe estoque em branco para ilimitado). Igual nos drops de
mob, ao salvar a lista de itens à venda substitui a anterior.

O vínculo "NPC concede a missão X" não fica no cadastro do NPC — ele
fica no cadastro da própria missão (`admin/missions.html`), no campo
opcional "NPC que concede". Marcar o papel "Concede missão" no NPC é
só organizativo/informativo; o vínculo de verdade (pra aparecer nas
duas páginas públicas) é esse campo na missão. Por isso, cadastre o
NPC antes da missão que ele concede.

Na página pública de NPCs (`npcs.html`) dá pra filtrar por arco e por
papel, e cada card mostra localização, descrição, o que o NPC vende
(com preço e estoque) e quais missões ele concede. Na página de
missões (`missions.html`), quando uma missão tem um NPC vinculado, o
card mostra "Concedida por: <nome do NPC>".

### NPCs pré-cadastrados (migração 014)

A migração `supabase/migrations/014_seed_npcs.sql` (espelhada no
`schema.sql`) cadastra **66 NPCs** extraídos de
[Category:NPC](https://ninonline.fandom.com/wiki/Category:NPC) e
[Category:NPCs](https://ninonline.fandom.com/wiki/Category:NPCs) (68
páginas ao todo, deduplicadas).

**Fora do escopo (6 páginas):** Guren já está cadastrado como mob boss
na migração 011; Guard Hayate, Guard Yetsuo, Eddie, Karoshi e Nina são
stubs de Bestiário sem nenhum stat capturado ("Not recorded" em tudo) —
não fazem sentido em `npcs` nem em `mobs` ainda.

**Lojas desmembradas:** as duas páginas "hub" de loja de roupas (Mist
Village Clothing Shop e Sand Village Clothing Shop) viraram os NPCs
individuais que de fato atendem o balcão — Tenma/Shimori/Gumi (Névoa) e
Sako/Mako/Gumi (Areia) — já que cada um tem estoque e papel próprios.

**Papéis (`roles`):** classificação heurística a partir do texto da
wiki (seção "Missions", verbo "sells"/"shop", menção como ponto de
entrega de itens etc.) — revise pelo Admin se algo saiu errado.

**`npc_shop_items` ficou de fora desta migração:** a maior parte do que
esses NPCs vendem é roupa (Clothes), que ainda não foi cadastrada na
tabela `items`. Os preços e itens ficaram documentados em texto livre
no campo "Descrição" de cada NPC; quando Clothes for cadastrado, popule
"Itens que vende" manualmente pelo Admin (ou numa migração futura).

**Localização (`arco_id`/`pin_id`)** fica null pra todos, mesmo padrão
da migração 011 (mobs) — posicionamento no mapa é manual, feito depois
pelo admin. O campo `location_note` (texto livre) já vem preenchido com
o local descrito na wiki.

**Missões vinculadas (`missions.giver_npc_id`):** a migração linka
automaticamente os 5 casos em que o nome da missão (migração 010) bate
sem ambiguidade com o NPC concedente — Warden Haoya (Your Best
Behavior / Prison Work / Bat Clearance) e Masumi/Himura (Medicine
Supplies II/IV). Os demais NPCs marcados como "Concede missão" ficam só
documentados em texto — cadastre o vínculo manualmente em
`admin/missions.html` quando a missão correspondente existir no banco.

### Página de detalhes do NPC (`npc-detail.html`)

Igual mob, o nome de cada NPC em `npcs.html` linka pra
`npc-detail.html?id=<uuid>`: imagem, descrição, tabela de itens à
venda (com preço/estoque) e lista de missões que ele concede. O campo
novo é `npcs.image_url` (migração 009), com upload no mesmo padrão dos
outros cadastros — campo "Imagem" em `admin/npcs.html`.

## Clothes (roupas/cosméticos)

A migração `supabase/migrations/015_seed_clothes.sql` (espelhada no
`schema.sql`) cadastra **306 roupas/cosméticos** documentados em
[ninonline.fandom.com/wiki/Category:Clothing](https://ninonline.fandom.com/wiki/Category:Clothing)
(335 páginas na categoria), como itens `type = 'roupa'` na tabela `items`
já existente — a última das quatro categorias do hub
[Items](https://ninonline.fandom.com/wiki/Items) da wiki (depois de
Weapons, migração 008; e Rings, migração 013; Consumable e Other items
seguem de fora por enquanto).

Adiciona sete colunas novas em `items` (nulas pra qualquer item que não
seja roupa): `clothing_slot` (Hat, Vest, Shirt, Mask, Pants, Accessory,
Cape, Outfit, Footwear... texto livre, não enum — a wiki não é
consistente o bastante pra um enum fechado), `clothing_rarity`
(Common/Uncommon/Rare/Legendary/Unique/Premium/Event/Crafted/Enchanted/
Drop/Clan/Cash/Recipe Drop), `clothing_level_required` (nível mínimo,
quando documentado), `clothing_price_ryo` (preço em Ryo como número, só
quando é um valor simples em Ryo), `clothing_price_text` (preço em texto
livre — cobre USD do Cash Shop, War Tokens, Event Coupons, Halloween
Token, "Not sold" pra recompensa de conquista etc.), `clothing_source`
(loja e/ou NPC de onde obter) e `clothing_notes` (lacunas de dados).

**Fora do escopo (29 páginas):** 4 são páginas-índice, não itens em si
("Event-exclusive items", "Role-gated equipment", "Mist Village Clothing
Shop" e "Sand Village Clothing Shop" — essas duas lojas já estão
documentadas via NPCs na migração 014). As outras 25 são páginas "hub"
de família de cor (ex. Adventure Cloak, War Mantle, Bandit Mask, Visor,
Barbarian Cloak) que só descrevem o conjunto — cada cor tem sua própria
página com dados completos (ex. Black Adventure Cloak, Blue War Mantle)
e foi essa página individual que entrou no cadastro. Um punhado de
famílias com nome parecido (Ragged Poncho, Jira Vest, Sakkat, Bear Hood,
High Heel Boots, Tenegui Towel Hat, Snake Rope Belt, Top Hat, Wanderer
Shirt) não são hubs — são item real e comprável por si só, com
preço/loja própria documentada na própria página, e por isso ficaram
dentro do cadastro.

**Reclassificação de itens de drop de mob:** cerca de 40 roupas desta
lista (Snake Rope Belt, Gas Mask, Beaded Necklace, Chest Bandages,
Tengai Hat, Wanderer Shirt, entre outras) já existiam em `items` como
`type = 'item_mob'`, criadas automaticamente pela migração 011 (mobs)
como placeholder sem descrição — na época Clothes ainda não tinha sido
cadastrado. Esta migração reclassifica esse placeholder pra
`type = 'roupa'` e preenche os dados, mas só quando o item ainda está
sem descrição — nunca sobrescreve um item de outro tipo real (arma,
anel, consumível) que por acaso tenha o mesmo nome, nem um item que o
admin já tenha editado manualmente.

**Lacunas de dados:** o parser descarta valores de raridade fora da
lista conhecida (a wiki tem ruído de formatação vazando pra esse campo
em algumas infoboxes antigas), deixando `clothing_rarity` null em vez
de lixo — revise pelo Admin caso encontre algo estranho. `npc_shop_items`
(itens à venda por NPC) não foi populado retroativamente por esta
migração; isso fica pra quando alguém quiser linkar os vendedores da
migração 014 aos itens agora cadastrados aqui.

## Montarias (Mounts)

A migração `supabase/migrations/016_seed_mounts.sql` (espelhada no
`schema.sql`) cria a tabela **`mounts`** e cadastra as **13 montarias**
documentadas em
[ninonline.fandom.com/wiki/Category:Mounts](https://ninonline.fandom.com/wiki/Category:Mounts)
(14 páginas na categoria). A 14ª página, **Taming Flute** (o item usado
pra domesticar as montarias tameáveis), não é uma montaria em si — foi
cadastrada em `items` como `type = 'consumivel'`, reaproveitando o
mesmo mecanismo de reclassificação de placeholder usado pelas Clothes
(migração 015): se já existisse como `item_mob` sem descrição, vira
`consumivel` com os dados preenchidos; se já foi editado manualmente
pelo Admin, não é sobrescrito.

Colunas de `mounts`:

- `is_starter` / `village_id` / `obtain_level`: as 3 montarias
  iniciais de vila — Boar (Névoa, nível 15), Tiger (Folha, nível 20) e
  Wolf (Areia, nível 20) — obtidas via missões de Domador de Feras da
  vila. As demais 10 não são iniciais (`is_starter = false`,
  `village_id` e `obtain_level` nulos).
- `flying`: hoje só a Hawk Mount — personagem renderiza acima da
  franja do cenário quando montado.
- `tame_target`: a criatura selvagem domesticável com a Taming Flute
  pra obter aquela montaria (null quando não é obtida por
  domesticação — ex: Tsuchigumo, que vem de drop de boss, e Lantern,
  que é comprada com Yokai Coin).
- `source`: resumo em texto livre de como obter.
- `notes`: detalhes extras (bônus de vantagem das iniciais, crédito de
  arte, ou aviso de que a wiki ainda não documentou o método).

**Lacunas de dados:** Hornet Mount e Clay Bird Black Mount têm método
de obtenção marcado como "ainda sendo documentado" pela própria wiki —
ficou registrado assim em `notes`, sem inventar dado.

## Organizações (Corps) e itens restritos

A migração `supabase/migrations/018_seed_organizations_and_restricted_items.sql`
(espelhada no `schema.sql`) cria a tabela **`organizations`** e cadastra
as **8 organizações oficiais** do jogo, extraídas de
[ninonline.fandom.com/wiki/Corps](https://ninonline.fandom.com/wiki/Corps)
e das páginas individuais de Kuronami, Medical Corps e Military Police:
ANBU, Twelve Guardian Ninja, The Sand Puppet Brigade, Seven Swordsmen of
the Mist, The Neo-Akatsuki, Military Police Force, Medical Corps e
Kuronami.

**Fora de escopo:** a página
[Organizations](https://ninonline.fandom.com/wiki/Organizations) da
wiki também lista 5 organizações feitas por **jogadores** (Desert
Pirates, Yoru, Taka, Red Lotus, Seigi) — são história/trivia de
servidor, grupos que já não existem mais, não um sistema do jogo ativo
hoje, então ficaram de fora.

Colunas de `organizations`:

- `village_id`: nulo quando a organização existe nas 3 vilas (Military
  Police Force, Medical Corps), é secreta/cross-vila (ANBU,
  Neo-Akatsuki), ou é baseada numa vila que não está na tabela
  `villages` (Kuronami, baseada em Takumi Village, que não é uma das 4
  vilas jogáveis cadastradas ali). Preenchido só quando a organização é
  exclusiva de uma das 4 vilas (Twelve Guardian Ninja = Folha, The Sand
  Puppet Brigade = Areia, Seven Swordsmen of the Mist = Névoa).
- `secret`: `true` pra ANBU e Neo-Akatsuki — a wiki diz explicitamente
  que organizações secretas não aparecem no bounty book do jogador.
  Kuronami não tem essa confirmação explícita na wiki, então ficou
  `false` mesmo sendo uma organização criminosa.
- `ranks`: lista ordenada (menor pro maior) só quando a wiki documenta
  uma hierarquia formal (ANBU, Puppet Brigade, Military Police).
  Twelve Guardian Ninja e Seven Swordsmen explicitamente **não têm**
  ranks/esquadrões formais (a própria wiki diz isso) — ficou vazio de
  propósito, não é lacuna de dado. Neo-Akatsuki, Medical Corps e
  Kuronami não têm uma lista de ranks documentada — também ficou vazio.

### Itens restritos por cargo/organização

A mesma migração cadastra os **10 itens role-gated** listados na página
[Role-gated equipment](https://ninonline.fandom.com/wiki/Role-gated_equipment):
Mist Special Division Mask/Robe, Mizukami Hat/Cloak, Sand Police Vest,
Yamato Protector, Black Flak Jacket, White Chunin Battle Suit, Tendo
Beserker Pants e Kuronami Ring.

9 desses itens **já existiam** em `items` como placeholders `type =
'roupa'` cadastrados pela migração 015 (descrição genérica "This is
role-gated..."); esta migração enriquece essas linhas com a descrição
completa e as novas colunas abaixo, sem recriá-las. O décimo, o
**Kuronami Ring**, ficou explicitamente fora de escopo da migração 013
(anéis) por ser restrito a organização — entra aqui como item novo,
`type = 'anel'`.

Três colunas novas em `items`, nulas pra qualquer item comum:

- `restricted_to`: quem pode equipar (organização, rank ou clã), texto
  livre — ex. "Mist Special Division (Névoa)", "Jonin", "Clã Tendo
  (elite)".
- `restricted_stat_bonus`: bônus de atributo em JSON, só quando o item
  dá bônus de verdade — a imensa maioria destes é puramente
  cosmética/de status; só a **Mist Special Division Mask** dá stats
  entre as 9 roupas (+7 em todos os 5 atributos, o maior bônus
  catalogado no site). Pro Kuronami Ring o bônus já vai em
  `ring_variants` (mesmo padrão da migração 013), então esta coluna
  fica nula nele.
- `restricted_notes`: mecânica extra do próprio jogo (ex. "cannot be
  traded" nas regalias do Mizukami, "drops on death" no Kuronami Ring)
  ou aviso de que o nível exigido no card é baixo o bastante pra ser
  irrelevante perto do requisito real (rank/organização/vila).

**Nota de nomenclatura não resolvida:** o nome do Kuronami Ring e o
efeito visual no jogo ("KuronamiGlow") usam o nome da organização
Kuronami, mas o texto da própria wiki diz que o anel é usado pelo
**Neo-Akatsuki** e dropa na "Neo-Akatsuki cave" — inconsistência da
wiki entre o nome do item e a organização associada, sinalizada em
`restricted_notes` e mantida como está.

**Lacunas de dados:** a forma de conseguir a maioria destes itens não é
documentada pela wiki (cargos/organizações concedem o item
automaticamente a membros, sem loja/NPC) — `clothing_source` fica null
nesses casos em vez de um chute.

## Itens da Cash Shop

A migração `supabase/migrations/019_seed_cash_shop_items.sql` (espelhada
no `schema.sql`) cadastra os itens da **Cash Shop** (loja de
[Nin Credits](https://ninonline.fandom.com/wiki/Nin_Credits), NC),
extraídos de [Cash Shop](https://ninonline.fandom.com/wiki/Cash_Shop) e
das páginas que ela referencia — **Outfits**, **Premium Hairstyles**,
**Skins & Eyes**, **Cash Shop Game Items** e **Furniture**. Ao todo,
**353 linhas** entram ou são enriquecidas.

Duas colunas novas em `items`, nulas pra item comum:

- `price_nc`: preço em Nin Credits (NC), a moeda paga da Cash Shop —
  separado de `clothing_price_ryo`/`clothing_price_text` (Ryo, ou o USD
  do Cash Shop antigo da migração 015) porque é um número pesquisável e
  se aplica tanto a roupas quanto a consumíveis desta migração.
- `price_nc_notes`: detalhes do card que não cabem em `price_nc` —
  stack size, se pode ser trocado/destruído, ou (pras hairstyles) a
  atualização/artista que a wiki documenta.

### Outfits, Pals e Functional (215 itens, 179 novos)

Da página [Outfits](https://ninonline.fandom.com/wiki/Outfits) — 36
já existiam em `items` como `type = 'roupa'` da migração 015
(cadastrados com preço em USD do Cash Shop antigo, entre eles o Rat
Pal) e só ganharam `price_nc` preenchido, sem tocar no que já estava
cadastrado. As outras 179 são novas, com `description` null — a página
só lista ícone, nome e preço, sem texto por item.

`clothing_slot` aqui é a seção da própria página da wiki (ex. "Vests,
Robes & Body", "Hats & Head", "Masks & Eyewear") em vez de um slot por
item — a página não detalha o slot de equipamento individual como as
páginas dedicadas usadas na migração 015. Duas sub-seções fogem do
padrão "roupa vestível":

- **Pals (8):** cosméticos de companion que seguem o personagem —
  `clothing_slot = 'Pet'`, mesmo padrão já usado pro Rat Pal.
- **Functional (6):** Merchant Cart, Summoner Scroll e 4 Military
  Carrier Scrolls de cor — utilidade que a wiki não detalha além do
  nome/preço. `clothing_slot = 'Functional'`, sem inventar mecânica.

### Premium Hairstyles (151 itens, todos novos)

Da página [Premium Hairstyles](https://ninonline.fandom.com/wiki/Premium_Hairstyles)
— 136 hairstyles Premium (890 NC) + 15 básicas (260 NC). Nenhuma
hairstyle tinha sido cadastrada antes. Entram como `type = 'roupa'`,
`clothing_slot = 'Hairstyle'`. Quando a wiki documenta a
atualização/artista de uma hairstyle específica, isso vai pro
`price_nc_notes` — a maioria não tem essa informação, a própria wiki
deixa em branco.

### Skins & Eyes e Cash Shop Game Items (20 itens, todos novos)

[Skins & Eyes](https://ninonline.fandom.com/wiki/Skins_%26_Eyes) (10:
mudam skin do corpo, cor/estilo de olho ou cor da montaria) e
[Cash Shop Game Items](https://ninonline.fandom.com/wiki/Cash_Shop_Game_Items)
(10: Name Changer, Scroll of Stat Reset, Inventory Expansion, World
Blessings etc.) entraram como `type = 'consumivel'` — são aplicados
uma vez, não equipados num slot permanente. O "New Ninja Free Gift" é
gratuito (a wiki marca "Free", não um valor em NC) — `price_nc` ficou
null com a nota explicando.

### Furniture (3 itens, todos novos)

Só os itens de [Furniture](https://ninonline.fandom.com/wiki/Furniture)
realmente vendidos na Cash Shop: **Grand Piano** (440 NC), **Palace
Pillar** (260 NC) e **White Neo Cash Register** (890 NC). Entram como
`type = 'roupa'`, `clothing_slot = 'Furniture'` — mobília não é
"vestível" no sentido literal, mas reaproveita a mesma coluna em vez de
criar uma tabela nova só pra 3 linhas.

**Fora de escopo:** a categoria Furniture da wiki tem 9 páginas no
total, mas 6 ficaram de fora por não serem itens de Cash Shop:
Battlefield Memorial, War Banner e War Pillar vêm da War Event Shop
(evento à parte); Chateau Bookshelf II e Dark Monkey King Trophy não
têm fonte de Cash Shop documentada (o segundo é drop de mob); e
Toranin Store é craftável, não comprável. Podem virar seu próprio
cadastro depois, ligados aos sistemas de evento/drop/crafting
correspondentes.

## Maestrias, jutsus e armas

Base de dados usada pela página de **builds** (`builds.html`) — o
cadastro em si.

### Maestrias (`admin/masteries.html`)

As 8 maestrias do jogo (Fogo, Vento, Raio, Terra, Água, Medicina, Arma
e Taijutsu) já vêm pré-cadastradas pela migração/schema — um
personagem escolhe uma no nível 10 e outra no nível 50. Cada maestria
tem nome, descrição, ícone (mesmo padrão dos itens, veja abaixo) e uma
lista opcional de **ramificações**: algumas maestrias se dividem em
dois focos diferentes, ex. Medicina tem "Foco em Chakra" e "Foco em
Dano (Intelecto)" — já vêm cadastradas por padrão, mas dá pra editar,
adicionar ou remover ramificações de qualquer maestria no formulário.
Maestria sem ramificação cadastrada é tratada como não tendo esse
nível de escolha extra. Ao salvar, a lista de ramificações do
formulário substitui a anterior (mesmo padrão dos drops de mob e dos
itens à venda de NPC).

Tem também um campo opcional **"Como jogar"** (`masteries.playstyle_notes`,
migração 009) — texto livre pra pontos fortes/fracos e notas de PvE x
PvP, no estilo do texto que o ninonline.fandom.com/wiki tem em cada
página de maestria (ex: `/wiki/Fire_Mastery`).

### Página de detalhes da maestria (`mastery-detail.html`)

O nome de cada maestria em `masteries.html` linka pra
`mastery-detail.html?id=<uuid>`: descrição, "Como jogar", ramificações
e a lista completa de jutsus dessa maestria (nome, rank, nível,
chakra, cooldown) — mais detalhe do que cabe no card da listagem.

### Jutsus (`admin/jutsus.html`)

Cada jutsu tem nome, maestria (obrigatória), ramificação (opcional —
só aparece disponível se a maestria escolhida tiver ramificações
cadastradas), rank (S/A/B/C/D — mesma escala das missões), nível
necessário, custo de chakra, cooldown (em segundos), descrição livre e
ícone. Dano, cura, alcance e área de efeito não viraram campos
estruturados — ficam livres na descrição, se quiser detalhar. Na
página pública (`jutsus.html`) dá pra filtrar por maestria e por rank.

### Armas (extensão do cadastro de itens)

Em vez de uma tabela separada, armas continuam sendo itens comuns
(`admin/items.html`, tipo "Arma"). Os campos "categoria antiga" /
"sinergia de maestria (antiga)" são os que já existiam antes e
continuam funcionando, mas o calculador de build usa os campos novos,
que batem com o jogo de verdade:

- **Grupo de arma**: `Blunt`, `Fan`, `Fist`, `Pipe`, `Seven Blades` ou
  `Sword` (os 6 grupos reais do jogo — bem diferente da categoria
  antiga de 5 opções, que era um chute inicial).
- **Dano base / Alcance**: os mesmos campos de antes, só que agora
  representam exatamente "Base Damage" / "Range" do jogo.
- **Raridade**: texto livre (Common, Rare, Legendary, etc.).
- **Auto ataque escala com Agilidade**: marque só pras armas que o
  jogo escala por Agilidade em vez de Força (algumas armas da
  categoria Fist, ex. Nunchaku, Manoplas).
- **Requisitos (JSON)**: nível e/ou atributo mínimo pra empunhar a
  arma, ex. `{"Level": 10, "Strength": 23}`. O calculador de build usa
  isso pra marcar a arma como bloqueada quando o personagem não
  atende.
- **Bônus (JSON)**: bônus que a arma dá quando equipada, ex.
  `{"Fortitude": "+3", "Bonus": "Knockback"}`. Bônus numéricos de
  atributo (`"+N"`) entram automaticamente no cálculo de status; os
  outros (`Bonus`, `Life Steal`, etc.) são só informativos.

Na listagem pública de itens (`items.html`), itens do tipo Arma
mostram a categoria (antiga) ao lado do tipo e têm colunas de Dano e
Alcance preenchidas (itens que não são armas mostram "—" nessas
colunas) — isso continua igual.

### Jutsus: requisito e dano (pro calculador de build)

Além dos campos que já existiam (rank, custo de chakra, cooldown —
ficam como informação extra), cada jutsu agora pode ter: atributo
exigido (STR/FORT/INT/AGI/CHK), valor exigido desse atributo, dano
base e um fator de escala. O calculador de build usa isso pra
mostrar/bloquear o jutsu e calcular o dano final:

```
dano final = dano base + (escala × valor total do atributo do personagem)
```

### Ícones de maestrias e jutsus

Maestrias e jutsus usam o mesmo bucket de Storage `item-icons` e a
mesma moldura `.item-icon-frame` já usados pelos itens — o helper de
upload/remoção (`js/storage-upload.js`) é compartilhado pelos três
formulários de admin, então não precisa configurar nada além do que
já foi feito pra itens (veja "Imagem (ícone) do item" acima).

## Builds (`builds.html`)

Calculador de build do personagem — mesma lógica do
[ninforge.xyz](https://ninforge.xyz/), reimplementada aqui em cima do
seu próprio cadastro de maestrias/armas/jutsus:

- **Personalização**: nome, nível (1–70), vila, 1ª e 2ª maestria,
  corporação e um slider de "buff de guild" (%) — o buff de guild
  soma, em cada atributo, `piso(atributo base × buff / 100)`.
- **Arma**: escolha por grupo (Blunt/Fan/Fist/Pipe/Seven
  Blades/Sword) e depois o modelo específico — cada modelo tem seus
  próprios requisitos e bônus (vem do cadastro de itens, ver acima). A
  arma fica marcada como bloqueada se o personagem não atende aos
  requisitos, mas isso não impede de montar a build.
- **Status**: 315 pontos pra distribuir num personagem nível 70 (a
  fórmula do pool de pontos por nível é a mesma do NinForge: 5 pontos
  por nível até 50, +4 por nível de 51 a 60, +3 por nível de 61 a 70).
  Vida, Chakra, Ataque básico, Kunai, Shuriken e Senbon são calculados
  a partir dos atributos totais (base + anéis + bônus da arma + buff
  de guild).
- **Anéis**: Anel Alfa e Anel Beta, cada um com 5 slots livres —
  escolha o atributo e o valor de cada slot (representa uma joia/roll
  do anel; não há um catálogo de anéis, é livre).
- **Jutsus**: abas por maestria escolhida (1ª/2ª), mostrando todos os
  jutsus daquela maestria com nível/atributo exigido e o dano
  calculado pro personagem atual; jutsu cujo requisito não é atendido
  aparece esmaecido e marcado "Bloqueado".
- **Salvar / Compartilhar**: "Salvar build" guarda a build no
  navegador (`localStorage`, lista em "Builds salvos" — não precisa de
  login nem do Supabase pra isso). "Compartilhar build" gera um link
  com a build inteira codificada na URL (`?b=...`) e copia pra área de
  transferência — quem abrir o link vê a build carregada, sem precisar
  de conta.

### De onde vieram os números do jogo

As 59 armas e ~90 jutsus (todas as maestrias, incluindo os jutsus de
nível 70 mais recentes) foram extraídos diretamente do código-fonte
público do ninforge.xyz e semeados pela migração
`008_add_build_system_data.sql`. As fórmulas de Vida/Chakra/Ataque
básico/Kunai/Shuriken/Senbon/pool de pontos também vêm de lá. Duas
ressalvas: (1) as constantes de Kunai/Shuriken/Senbon (base 20, escala
0.5) foram calibradas comparando com os números exibidos no site ao
vivo, já que o valor exato configurado no admin do NinForge não é
público; (2) habilidades especiais de nicho (bisturi de chakra, ponto
de pressão, selo amaldiçoado, bônus de corporação médica) não foram
implementadas nesta primeira versão — dá pra adicionar depois se
fizer falta.

## Publicar no GitHub Pages

1. Suba esta pasta para um repositório no GitHub (o projeto já tem um
   repositório git local iniciado).
2. No GitHub, vá em **Settings → Pages**.
3. Em "Source", selecione a branch (ex: `main`) e a pasta (`/root` ou
   `/site`, dependendo de onde ficarem os arquivos).
4. Salve — o GitHub Pages vai gerar uma URL pública em alguns minutos.

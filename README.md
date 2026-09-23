# Nin.Map

Mapa interativo do mundo de **Nin Online**, feito com [Leaflet](https://leafletjs.com/).

## Como funciona

O mapa usa o modo `L.CRS.Simple` do Leaflet, que trata a imagem do mapa como
um plano de coordenadas (x, y) ao invés de coordenadas geográficas — é a
forma padrão de exibir mapas de jogos (não é o mundo real).

## Estrutura

```
site/
├── index.html                  # mapa principal (com seletor de arco)
├── missions.html                # listagem pública de missões
├── css/style.css                 # estilos (site + admin)
├── js/config.js                  # lista de arcos (mapas instanciados)
├── js/map.js                     # lógica do mapa (Leaflet + pins do Supabase)
├── js/missions.js                # lógica da listagem de missões
├── js/missions-shared.js         # helpers de formatação (nível, objetivos)
├── js/supabase-config.js         # URL + anon key do seu projeto Supabase
├── js/supabaseClient.js          # cliente Supabase compartilhado
├── assets/map-arco*.jpg          # imagem de cada arco (placeholders por enquanto)
├── data/locations.example.json   # exemplo de formato para marcadores
├── supabase/schema.sql           # schema do banco (tabelas, RLS)
└── admin/                        # área de cadastro (login + CRUD)
    ├── index.html                 # login
    ├── pins.html                  # cadastro de pins (clique no mapa)
    ├── missions.html               # cadastro de missões
    └── js/                         # auth.js, login.js, pins-admin.js, missions-admin.js
```

## Arcos (mapas instanciados)

O site tem um seletor no topo para trocar entre os arcos do jogo — hoje:
Arco 20, Arco 30, Arco 50 e Arco 60. Cada arco é um mapa independente,
com sua própria imagem e seus próprios marcadores.

A escolha do arco fica salva (no navegador) e também na URL, ex:
`index.html?arco=30` — então dá pra compartilhar um link já apontando
pro arco certo.

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
   `supabase/schema.sql` e rode. Isso cria as tabelas `arcos`, `pins`,
   `missions` e as políticas de segurança (RLS).
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
- `admin/missions.html` — cadastra nome, descrição, XP, ryo, tipo da
  missão (global, exclusiva de arco, evento ou diária), nível
  necessário (exato, mínimo, até um nível, ou intervalo) e os objetivos
  (lista de item + quantidade, com botão para adicionar mais itens).

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

## Publicar no GitHub Pages

1. Suba esta pasta para um repositório no GitHub (o projeto já tem um
   repositório git local iniciado).
2. No GitHub, vá em **Settings → Pages**.
3. Em "Source", selecione a branch (ex: `main`) e a pasta (`/root` ou
   `/site`, dependendo de onde ficarem os arquivos).
4. Salve — o GitHub Pages vai gerar uma URL pública em alguns minutos.

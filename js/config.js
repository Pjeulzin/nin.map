/**
 * Configuração dos arcos (mapas instanciados) de Nin Online.
 *
 * Cada arco é um mapa independente. Para adicionar/editar um arco:
 *   - id: identificador único (usado na URL, ex: ?arco=20)
 *   - label: nome exibido no seletor
 *   - image: caminho da imagem do mapa
 *   - width / height: dimensões reais da imagem em pixels
 *   - locations: pontos de interesse desse arco (opcional, mesmo formato
 *     de data/locations.example.json)
 */

const ARCOS = [
  {
    id: "20",
    label: "Arco 20",
    image: "assets/map-arco20.jpg",
    width: 2048,
    height: 2048,
    locations: [],
  },
  {
    id: "30",
    label: "Arco 30",
    image: "assets/map-arco30.jpg",
    width: 2048,
    height: 2048,
    locations: [],
  },
  {
    id: "50",
    label: "Arco 50",
    image: "assets/map-arco50.jpg",
    width: 2048,
    height: 2048,
    locations: [],
  },
  {
    id: "60",
    label: "Arco 60",
    image: "assets/map-arco60.jpg",
    width: 2048,
    height: 2048,
    locations: [],
  },
];

const DEFAULT_ARCO_ID = ARCOS[0].id;

export { ARCOS, DEFAULT_ARCO_ID };

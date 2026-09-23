/**
 * Nin.Map — mapa interativo do mundo de Nin Online, com suporte a
 * múltiplos arcos (mapas instanciados).
 *
 * Usa Leaflet no modo CRS.Simple, que trata a imagem do mapa como um
 * plano cartesiano (x, y) em vez de coordenadas geográficas — o modo
 * padrão para mapas de jogos.
 *
 * A lista de arcos disponíveis fica em js/config.js. Os pins (pontos de
 * interesse) vêm do Supabase — veja supabase/schema.sql e
 * js/supabase-config.js. Enquanto o Supabase não estiver configurado,
 * cai de volta nos `locations` definidos em cada arco no config.js.
 */

import { ARCOS, DEFAULT_ARCO_ID, VILLAGES } from "./config.js";
import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { getCurrentVillage, storeVillage, updateVillageInUrl } from "./village.js";
import { mountGlobalControls } from "./chrome.js";
import { applyStaticTranslations, pickLabel } from "./i18n.js";

const markerIcons = {
  cidade: "🏘️",
  dungeon: "🗡️",
  npc: "🧙",
  recurso: "🌲",
  outro: "📍",
  default: "📍",
};

let map = null;
let imageLayer = null;
let markerLayer = null;

function getArcoById(id) {
  return ARCOS.find((a) => a.id === id) || ARCOS[0];
}

function getArcoFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("arco");
  return id && ARCOS.some((a) => a.id === id) ? id : null;
}

function getStoredArco() {
  try {
    return localStorage.getItem("ninmap:arco");
  } catch (e) {
    return null;
  }
}

function storeArco(id) {
  try {
    localStorage.setItem("ninmap:arco", id);
  } catch (e) {
    /* ambiente sem localStorage disponível — ignora */
  }
}

function updateUrl(id) {
  const params = new URLSearchParams(window.location.search);
  params.set("arco", id);
  const newUrl = `${window.location.pathname}?${params.toString()}`;
  window.history.replaceState({}, "", newUrl);
}

function renderPins(pins) {
  markerLayer.clearLayers();
  pins.forEach((pin) => {
    const icon = L.divIcon({
      html: `<span style="font-size:22px;">${markerIcons[pin.type] || markerIcons.default}</span>`,
      className: "",
      iconSize: [24, 24],
      iconAnchor: [12, 12],
    });

    L.marker([pin.y, pin.x], { icon })
      .addTo(markerLayer)
      .bindPopup(`<strong>${pin.name}</strong>${pin.description ? `<br>${pin.description}` : ""}`);
  });
}

async function fetchPinsForArco(arco) {
  if (!isSupabaseConfigured) {
    // Supabase ainda não configurado (js/supabase-config.js com placeholders)
    // — usa os locations de exemplo definidos no config.js, se houver.
    return arco.locations || [];
  }

  const { data, error } = await supabase
    .from("pins")
    .select("name, type, x, y, description")
    .eq("arco_id", arco.id);

  if (error) {
    console.error("Erro ao carregar pins do Supabase:", error.message);
    return arco.locations || [];
  }

  return data || [];
}

async function loadArco(id) {
  const arco = getArcoById(id);
  const bounds = [
    [0, 0],
    [arco.height, arco.width],
  ];

  if (!map) {
    map = L.map("map", {
      crs: L.CRS.Simple,
      minZoom: -2,
      maxZoom: 3,
      zoomSnap: 0.25,
      attributionControl: false,
    });
  }

  if (imageLayer) {
    map.removeLayer(imageLayer);
  }
  if (!markerLayer) {
    markerLayer = L.layerGroup().addTo(map);
  }

  imageLayer = L.imageOverlay(arco.image, bounds).addTo(map);
  map.fitBounds(bounds);

  document.getElementById("arco-select").value = arco.id;
  storeArco(arco.id);
  updateUrl(arco.id);

  const pins = await fetchPinsForArco(arco);
  renderPins(pins);
}

function populateArcoSelect() {
  const select = document.getElementById("arco-select");
  select.innerHTML = "";
  ARCOS.forEach((arco) => {
    const option = document.createElement("option");
    option.value = arco.id;
    option.textContent = pickLabel(arco);
    select.appendChild(option);
  });
  select.addEventListener("change", (e) => loadArco(e.target.value));
}

function populateVillageSelect() {
  const select = document.getElementById("village-select");
  VILLAGES.forEach((village) => {
    const option = document.createElement("option");
    option.value = village.id;
    option.textContent = pickLabel(village);
    select.appendChild(option);
  });

  const current = getCurrentVillage();
  if (current) select.value = current;

  select.addEventListener("change", (e) => {
    storeVillage(e.target.value || null);
    updateVillageInUrl(e.target.value || null);
  });
}

function refreshArcoAndVillageLabels() {
  const arcoSelect = document.getElementById("arco-select");
  Array.from(arcoSelect.options).forEach((opt) => {
    opt.textContent = pickLabel(getArcoById(opt.value));
  });

  const villageSelect = document.getElementById("village-select");
  Array.from(villageSelect.options).forEach((opt) => {
    if (!opt.value) return; // deixa o placeholder (data-i18n) em paz
    const village = VILLAGES.find((v) => v.id === opt.value);
    if (village) opt.textContent = pickLabel(village);
  });
}

function init() {
  mountGlobalControls();
  applyStaticTranslations();

  populateArcoSelect();
  populateVillageSelect();

  const initialId = getArcoFromUrl() || getStoredArco() || DEFAULT_ARCO_ID;
  loadArco(getArcoById(initialId).id);

  document.getElementById("btn-reset-view").addEventListener("click", () => {
    const arco = getArcoById(document.getElementById("arco-select").value);
    map.fitBounds([
      [0, 0],
      [arco.height, arco.width],
    ]);
  });

  if (!isSupabaseConfigured) {
    console.warn(
      "Supabase não configurado ainda — edite js/supabase-config.js com a URL e a anon key do seu projeto."
    );
  }

  window.addEventListener("ninmap:langchange", refreshArcoAndVillageLabels);
}

init();

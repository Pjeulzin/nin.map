import { ARCOS, DEFAULT_ARCO_ID } from "../../js/config.js";
import { supabase } from "../../js/supabaseClient.js";
import { requireAuth, wireLogoutButton } from "./auth.js";

await requireAuth();
wireLogoutButton();

const markerIcons = {
  cidade: "🏘️",
  dungeon: "🗡️",
  npc: "🧙",
  recurso: "🌲",
  outro: "📍",
};

const arcoSelect = document.getElementById("arco-select");
const form = document.getElementById("pin-form");
const formTitle = document.getElementById("form-title");
const idInput = document.getElementById("pin-id");
const nameInput = document.getElementById("pin-name");
const typeInput = document.getElementById("pin-type");
const xInput = document.getElementById("pin-x");
const yInput = document.getElementById("pin-y");
const descInput = document.getElementById("pin-description");
const errorEl = document.getElementById("pin-error");
const cancelBtn = document.getElementById("btn-cancel-edit");
const statusEl = document.getElementById("pins-status");
const tbody = document.getElementById("pins-tbody");

let map = null;
let imageLayer = null;
let markerLayer = null;
let pendingMarker = null;
let currentArco = null;

function getArcoById(id) {
  return ARCOS.find((a) => a.id === id) || ARCOS[0];
}

function populateArcoSelect() {
  arcoSelect.innerHTML = "";
  ARCOS.forEach((arco) => {
    const option = document.createElement("option");
    option.value = arco.id;
    option.textContent = arco.label;
    arcoSelect.appendChild(option);
  });
  arcoSelect.addEventListener("change", () => loadArco(arcoSelect.value));
}

function resetForm() {
  idInput.value = "";
  nameInput.value = "";
  typeInput.value = "outro";
  xInput.value = "";
  yInput.value = "";
  descInput.value = "";
  errorEl.textContent = "";
  formTitle.textContent = "Novo pin";
  cancelBtn.style.display = "none";
  if (pendingMarker) {
    markerLayer.removeLayer(pendingMarker);
    pendingMarker = null;
  }
}

function setPendingMarkerPosition(x, y) {
  if (pendingMarker) markerLayer.removeLayer(pendingMarker);
  pendingMarker = L.marker([y, x], {
    icon: L.divIcon({
      html: `<span style="font-size:24px;">🎯</span>`,
      className: "",
      iconSize: [26, 26],
      iconAnchor: [13, 22],
    }),
  }).addTo(markerLayer);
}

function loadArco(id) {
  currentArco = getArcoById(id);
  const bounds = [
    [0, 0],
    [currentArco.height, currentArco.width],
  ];

  if (!map) {
    map = L.map("map", {
      crs: L.CRS.Simple,
      minZoom: -2,
      maxZoom: 3,
      zoomSnap: 0.25,
      attributionControl: false,
    });
    map.on("click", (e) => {
      const x = Math.round(e.latlng.lng);
      const y = Math.round(e.latlng.lat);
      xInput.value = x;
      yInput.value = y;
      setPendingMarkerPosition(x, y);
    });
  }

  if (imageLayer) map.removeLayer(imageLayer);
  imageLayer = L.imageOverlay(currentArco.image, bounds).addTo(map);
  map.fitBounds(bounds);

  if (markerLayer) map.removeLayer(markerLayer);
  markerLayer = L.layerGroup().addTo(map);
  pendingMarker = null;

  resetForm();
  loadPins();
}

async function loadPins() {
  statusEl.textContent = "Carregando...";
  tbody.innerHTML = "";

  const { data, error } = await supabase
    .from("pins")
    .select("*")
    .eq("arco_id", currentArco.id)
    .order("name");

  if (error) {
    statusEl.textContent = `Erro: ${error.message}`;
    return;
  }

  statusEl.textContent = data.length === 0 ? "Nenhum pin cadastrado neste arco ainda." : "";

  data.forEach((pin) => {
    const marker = L.marker([pin.y, pin.x], {
      icon: L.divIcon({
        html: `<span style="font-size:22px;">${markerIcons[pin.type] || "📍"}</span>`,
        className: "",
        iconSize: [24, 24],
        iconAnchor: [12, 12],
      }),
    })
      .addTo(markerLayer)
      .bindPopup(`<strong>${pin.name}</strong>${pin.description ? `<br>${pin.description}` : ""}`);

    marker.on("click", () => fillFormForEdit(pin));

    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${pin.name}</td>
      <td>${pin.type}</td>
      <td style="white-space:nowrap;">
        <button type="button" class="btn btn-small" data-action="edit">Editar</button>
        <button type="button" class="btn btn-small btn-danger" data-action="delete">Excluir</button>
      </td>
    `;
    tr.querySelector('[data-action="edit"]').addEventListener("click", () => fillFormForEdit(pin));
    tr.querySelector('[data-action="delete"]').addEventListener("click", () => deletePin(pin));
    tbody.appendChild(tr);
  });
}

function fillFormForEdit(pin) {
  idInput.value = pin.id;
  nameInput.value = pin.name;
  typeInput.value = pin.type;
  xInput.value = pin.x;
  yInput.value = pin.y;
  descInput.value = pin.description || "";
  formTitle.textContent = `Editando: ${pin.name}`;
  cancelBtn.style.display = "inline-block";
  setPendingMarkerPosition(pin.x, pin.y);
  window.scrollTo({ top: 0, behavior: "smooth" });
}

async function deletePin(pin) {
  if (!confirm(`Excluir o pin "${pin.name}"?`)) return;
  const { error } = await supabase.from("pins").delete().eq("id", pin.id);
  if (error) {
    alert(`Erro ao excluir: ${error.message}`);
    return;
  }
  markerLayer.clearLayers();
  loadArco(currentArco.id);
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  errorEl.textContent = "";

  const payload = {
    arco_id: currentArco.id,
    name: nameInput.value.trim(),
    type: typeInput.value,
    x: Number(xInput.value),
    y: Number(yInput.value),
    description: descInput.value.trim() || null,
  };

  if (!payload.name || Number.isNaN(payload.x) || Number.isNaN(payload.y)) {
    errorEl.textContent = "Preencha nome e clique no mapa pra definir X/Y.";
    return;
  }

  const editingId = idInput.value;
  const { error } = editingId
    ? await supabase.from("pins").update(payload).eq("id", editingId)
    : await supabase.from("pins").insert(payload);

  if (error) {
    errorEl.textContent = `Erro ao salvar: ${error.message}`;
    return;
  }

  markerLayer.clearLayers();
  loadArco(currentArco.id);
});

cancelBtn.addEventListener("click", () => {
  markerLayer.clearLayers();
  loadPins();
  resetForm();
});

populateArcoSelect();
loadArco(DEFAULT_ARCO_ID);

import { ARCOS, VILLAGES } from "../../js/config.js";
import { supabase } from "../../js/supabaseClient.js";
import { requireAuth, wireLogoutButton } from "./auth.js";
import { MISSION_TYPE_LABELS, formatLevelRequirement, formatObjectives } from "../../js/missions-shared.js";

await requireAuth();
wireLogoutButton();

const form = document.getElementById("mission-form");
const formTitle = document.getElementById("form-title");
const idInput = document.getElementById("mission-id");
const nameInput = document.getElementById("mission-name");
const descInput = document.getElementById("mission-description");
const typeInput = document.getElementById("mission-type");
const arcoField = document.getElementById("mission-arco-field");
const arcoInput = document.getElementById("mission-arco");
const rankInput = document.getElementById("mission-rank");
const villageInput = document.getElementById("mission-village");
const npcInput = document.getElementById("mission-npc");
const xpInput = document.getElementById("mission-xp");
const ryoInput = document.getElementById("mission-ryo");
const levelModeInput = document.getElementById("mission-level-mode");
const levelMinField = document.getElementById("level-min-field");
const levelMaxField = document.getElementById("level-max-field");
const levelMinInput = document.getElementById("mission-level-min");
const levelMaxInput = document.getElementById("mission-level-max");
const objectivesList = document.getElementById("objectives-list");
const addObjectiveBtn = document.getElementById("btn-add-objective");
const errorEl = document.getElementById("mission-error");
const cancelBtn = document.getElementById("btn-cancel-edit");
const duplicateBtn = document.getElementById("btn-duplicate");
const statusEl = document.getElementById("missions-status");
const tbody = document.getElementById("missions-tbody");

function populateArcoSelect() {
  arcoInput.innerHTML = "";
  ARCOS.forEach((arco) => {
    const option = document.createElement("option");
    option.value = arco.id;
    option.textContent = arco.label;
    arcoInput.appendChild(option);
  });
}

function populateVillageSelect() {
  VILLAGES.forEach((village) => {
    const option = document.createElement("option");
    option.value = village.id;
    option.textContent = village.label;
    villageInput.appendChild(option);
  });
}

function villageLabel(villageId) {
  const village = VILLAGES.find((v) => v.id === villageId);
  return village ? village.label : villageId;
}

let allNpcs = [];

async function loadNpcOptions() {
  const { data, error } = await supabase.from("npcs").select("id, name").order("name");
  if (error) {
    console.error("Erro ao carregar NPCs:", error.message);
    return;
  }
  allNpcs = data || [];
  npcInput.innerHTML = '<option value="">— Não definido —</option>';
  allNpcs.forEach((npc) => {
    const option = document.createElement("option");
    option.value = npc.id;
    option.textContent = npc.name;
    npcInput.appendChild(option);
  });
}

function npcLabel(npcId) {
  const npc = allNpcs.find((n) => n.id === npcId);
  return npc ? npc.name : null;
}

function updateArcoFieldVisibility() {
  arcoField.style.display = typeInput.value === "arco" ? "flex" : "none";
}

function updateLevelFieldsVisibility() {
  const mode = levelModeInput.value;
  levelMinField.style.display = mode === "min" || mode === "range" || mode === "exact" ? "flex" : "none";
  levelMaxField.style.display = mode === "max" || mode === "range" ? "flex" : "none";
  if (mode === "exact") {
    levelMinField.querySelector("label").textContent = "Nível";
  } else {
    levelMinField.querySelector("label").textContent = "Nível mínimo";
  }
}

function addObjectiveRow(item = "", quantity = "") {
  const row = document.createElement("div");
  row.className = "objective-row";
  row.innerHTML = `
    <input type="text" placeholder="Item (ex: Cocoon)" class="objective-item" value="${item}" />
    <input type="number" placeholder="Qtd" min="1" class="objective-qty" style="max-width:90px;" value="${quantity}" />
    <button type="button" class="btn btn-small btn-danger" title="Remover">✕</button>
  `;
  row.querySelector("button").addEventListener("click", () => row.remove());
  objectivesList.appendChild(row);
}

function getObjectivesFromForm() {
  return Array.from(objectivesList.querySelectorAll(".objective-row"))
    .map((row) => ({
      item: row.querySelector(".objective-item").value.trim(),
      quantity: Number(row.querySelector(".objective-qty").value),
    }))
    .filter((o) => o.item && !Number.isNaN(o.quantity) && o.quantity > 0);
}

function resetForm() {
  idInput.value = "";
  nameInput.value = "";
  descInput.value = "";
  typeInput.value = "global";
  rankInput.value = "D";
  villageInput.value = "";
  npcInput.value = "";
  xpInput.value = 0;
  ryoInput.value = 0;
  levelModeInput.value = "range";
  levelMinInput.value = "";
  levelMaxInput.value = "";
  objectivesList.innerHTML = "";
  addObjectiveRow();
  errorEl.textContent = "";
  formTitle.textContent = "Nova missão";
  cancelBtn.style.display = "none";
  duplicateBtn.style.display = "none";
  updateArcoFieldVisibility();
  updateLevelFieldsVisibility();
}

function levelModeAndValuesFromMission(m) {
  const min = m.level_min;
  const max = m.level_max;
  if (min !== null && min !== undefined && max !== null && max !== undefined) {
    return min === max ? { mode: "exact", min, max: null } : { mode: "range", min, max };
  }
  if (min !== null && min !== undefined) return { mode: "min", min, max: null };
  if (max !== null && max !== undefined) return { mode: "max", min: null, max };
  return { mode: "range", min: null, max: null };
}

function fillFormForEdit(m) {
  idInput.value = m.id;
  nameInput.value = m.name;
  descInput.value = m.description || "";
  typeInput.value = m.mission_type;
  if (m.mission_type === "arco" && m.arco_id) arcoInput.value = m.arco_id;
  rankInput.value = m.rank || "D";
  villageInput.value = m.village_id || "";
  npcInput.value = m.giver_npc_id || "";
  xpInput.value = m.xp ?? 0;
  ryoInput.value = m.ryo ?? 0;

  const { mode, min, max } = levelModeAndValuesFromMission(m);
  levelModeInput.value = mode;
  levelMinInput.value = min ?? "";
  levelMaxInput.value = mode === "exact" ? "" : max ?? "";

  objectivesList.innerHTML = "";
  (m.objectives || []).forEach((o) => addObjectiveRow(o.item, o.quantity));
  if ((m.objectives || []).length === 0) addObjectiveRow();

  formTitle.textContent = `Editando: ${m.name}`;
  cancelBtn.style.display = "inline-block";
  duplicateBtn.style.display = "inline-block";
  updateArcoFieldVisibility();
  updateLevelFieldsVisibility();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function buildPayloadFromForm() {
  const mode = levelModeInput.value;
  const minVal = levelMinInput.value === "" ? null : Number(levelMinInput.value);
  const maxVal = levelMaxInput.value === "" ? null : Number(levelMaxInput.value);

  let level_min = null;
  let level_max = null;
  if (mode === "exact") {
    level_min = minVal;
    level_max = minVal;
  } else if (mode === "min") {
    level_min = minVal;
  } else if (mode === "max") {
    level_max = maxVal;
  } else if (mode === "range") {
    level_min = minVal;
    level_max = maxVal;
  }

  return {
    name: nameInput.value.trim(),
    description: descInput.value.trim() || null,
    mission_type: typeInput.value,
    arco_id: typeInput.value === "arco" ? arcoInput.value : null,
    rank: rankInput.value,
    village_id: villageInput.value || null,
    giver_npc_id: npcInput.value || null,
    xp: Number(xpInput.value) || 0,
    ryo: Number(ryoInput.value) || 0,
    level_min,
    level_max,
    objectives: getObjectivesFromForm(),
  };
}

function validatePayload(payload) {
  if (!payload.name) return "Informe o nome da missão.";
  if (payload.mission_type === "arco" && !payload.arco_id) return "Selecione o arco dessa missão.";
  return null;
}

async function loadMissions() {
  statusEl.textContent = "Carregando...";
  tbody.innerHTML = "";

  const { data, error } = await supabase
    .from("missions")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) {
    statusEl.textContent = `Erro: ${error.message}`;
    return;
  }

  statusEl.textContent = data.length === 0 ? "Nenhuma missão cadastrada ainda." : "";

  data.forEach((m) => {
    const tr = document.createElement("tr");
    const typeLabel = MISSION_TYPE_LABELS[m.mission_type] || m.mission_type;
    tr.innerHTML = `
      <td>${m.name}</td>
      <td>${m.rank || "D"}</td>
      <td>${typeLabel}${m.mission_type === "arco" && m.arco_id ? ` (${m.arco_id})` : ""}</td>
      <td>${m.village_id ? villageLabel(m.village_id) : "—"}</td>
      <td>${m.giver_npc_id ? npcLabel(m.giver_npc_id) || "—" : "—"}</td>
      <td>${formatLevelRequirement(m.level_min, m.level_max)}</td>
      <td>${m.xp ?? 0}</td>
      <td>${m.ryo ?? 0}</td>
      <td style="white-space:nowrap;">
        <button type="button" class="btn btn-small" data-action="edit">Editar</button>
        <button type="button" class="btn btn-small btn-danger" data-action="delete">Excluir</button>
      </td>
    `;
    tr.querySelector('[data-action="edit"]').addEventListener("click", () => fillFormForEdit(m));
    tr.querySelector('[data-action="delete"]').addEventListener("click", () => deleteMission(m));
    tbody.appendChild(tr);
  });
}

async function deleteMission(m) {
  if (!confirm(`Excluir a missão "${m.name}"?`)) return;
  const { error } = await supabase.from("missions").delete().eq("id", m.id);
  if (error) {
    alert(`Erro ao excluir: ${error.message}`);
    return;
  }
  loadMissions();
}

typeInput.addEventListener("change", updateArcoFieldVisibility);
levelModeInput.addEventListener("change", updateLevelFieldsVisibility);
addObjectiveBtn.addEventListener("click", () => addObjectiveRow());

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  errorEl.textContent = "";

  const payload = buildPayloadFromForm();
  const validationError = validatePayload(payload);
  if (validationError) {
    errorEl.textContent = validationError;
    return;
  }

  const editingId = idInput.value;
  const { error } = editingId
    ? await supabase.from("missions").update(payload).eq("id", editingId)
    : await supabase.from("missions").insert(payload);

  if (error) {
    errorEl.textContent = `Erro ao salvar: ${error.message}`;
    return;
  }

  resetForm();
  loadMissions();
});

// Salva os dados atuais do formulário como uma missão NOVA (insert),
// sem mexer na que está sendo editada — útil pra criar a variante de
// outra vila de uma missão diária: edite o nome/objetivos/vila e
// clique aqui em vez de "Salvar".
duplicateBtn.addEventListener("click", async () => {
  errorEl.textContent = "";

  const payload = buildPayloadFromForm();
  const validationError = validatePayload(payload);
  if (validationError) {
    errorEl.textContent = validationError;
    return;
  }

  const { error } = await supabase.from("missions").insert(payload);
  if (error) {
    errorEl.textContent = `Erro ao duplicar: ${error.message}`;
    return;
  }

  resetForm();
  loadMissions();
});

cancelBtn.addEventListener("click", resetForm);

populateArcoSelect();
populateVillageSelect();
await loadNpcOptions();
resetForm();
loadMissions();

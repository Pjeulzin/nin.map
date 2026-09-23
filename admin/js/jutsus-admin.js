import { supabase } from "../../js/supabaseClient.js";
import { requireAuth, wireLogoutButton } from "./auth.js";
import { uploadImage, deleteImageFromStorage } from "../../js/storage-upload.js";

await requireAuth();
wireLogoutButton();

const form = document.getElementById("jutsu-form");
const formTitle = document.getElementById("form-title");
const idInput = document.getElementById("jutsu-id");
const nameInput = document.getElementById("jutsu-name");
const masteryInput = document.getElementById("jutsu-mastery");
const branchInput = document.getElementById("jutsu-branch");
const rankInput = document.getElementById("jutsu-rank");
const levelInput = document.getElementById("jutsu-level");
const chakraInput = document.getElementById("jutsu-chakra");
const cooldownInput = document.getElementById("jutsu-cooldown");
const statReqStatInput = document.getElementById("jutsu-stat-req-stat");
const statReqValueInput = document.getElementById("jutsu-stat-req-value");
const jutsuBaseDamageInput = document.getElementById("jutsu-base-damage");
const jutsuScalingInput = document.getElementById("jutsu-scaling");
const descInput = document.getElementById("jutsu-description");
const imageInput = document.getElementById("jutsu-image");
const imagePreview = document.getElementById("jutsu-image-preview");
const removeImageBtn = document.getElementById("btn-remove-image");
const errorEl = document.getElementById("jutsu-error");
const cancelBtn = document.getElementById("btn-cancel-edit");
const statusEl = document.getElementById("jutsus-status");
const tbody = document.getElementById("jutsus-tbody");
const masteryFilterEl = document.getElementById("jutsus-mastery-filter");

let allMasteries = [];
let allJutsus = [];
let currentImageUrl = null;
let removeImageRequested = false;

function iconFrameHtml(url, { empty = "Sem imagem" } = {}) {
  return url ? `<img src="${url}" alt="" />` : `<span class="item-icon-frame__empty">${empty}</span>`;
}

function setPreview(url) {
  imagePreview.innerHTML = iconFrameHtml(url);
  removeImageBtn.style.display = url ? "inline-block" : "none";
}

function masteryName(id) {
  const mastery = allMasteries.find((m) => m.id === id);
  return mastery ? mastery.name : null;
}

function refreshBranchOptions(masteryId, selectedBranchId) {
  const mastery = allMasteries.find((m) => m.id === masteryId);
  const branches = (mastery && mastery.mastery_branches) || [];
  branchInput.innerHTML = '<option value="">— Nenhuma —</option>';
  branches.forEach((b) => {
    const option = document.createElement("option");
    option.value = b.id;
    option.textContent = b.name;
    branchInput.appendChild(option);
  });
  branchInput.disabled = branches.length === 0;
  if (selectedBranchId) branchInput.value = selectedBranchId;
}

async function loadMasteryOptions() {
  const { data, error } = await supabase
    .from("masteries")
    .select("id, name, mastery_branches(id, name)")
    .order("name");
  if (error) {
    console.error("Erro ao carregar maestrias:", error.message);
    return;
  }
  allMasteries = data || [];

  masteryInput.innerHTML = '<option value="">— Não definida —</option>';
  masteryFilterEl.innerHTML = '<option value="">Todas as maestrias</option>';
  allMasteries.forEach((m) => {
    const opt1 = document.createElement("option");
    opt1.value = m.id;
    opt1.textContent = m.name;
    masteryInput.appendChild(opt1);

    const opt2 = document.createElement("option");
    opt2.value = m.id;
    opt2.textContent = m.name;
    masteryFilterEl.appendChild(opt2);
  });

  refreshBranchOptions("");
}

function resetForm() {
  idInput.value = "";
  nameInput.value = "";
  masteryInput.value = "";
  refreshBranchOptions("");
  rankInput.value = "";
  levelInput.value = "";
  chakraInput.value = "";
  cooldownInput.value = "";
  statReqStatInput.value = "";
  statReqValueInput.value = "";
  jutsuBaseDamageInput.value = "";
  jutsuScalingInput.value = "";
  descInput.value = "";
  imageInput.value = "";
  currentImageUrl = null;
  removeImageRequested = false;
  setPreview(null);
  errorEl.textContent = "";
  formTitle.textContent = "Novo jutsu";
  cancelBtn.style.display = "none";
}

function fillFormForEdit(jutsu) {
  idInput.value = jutsu.id;
  nameInput.value = jutsu.name;
  masteryInput.value = jutsu.mastery_id || "";
  refreshBranchOptions(jutsu.mastery_id || "", jutsu.mastery_branch_id || "");
  rankInput.value = jutsu.rank || "";
  levelInput.value = jutsu.level_required ?? "";
  chakraInput.value = jutsu.chakra_cost ?? "";
  cooldownInput.value = jutsu.cooldown_seconds ?? "";
  statReqStatInput.value = jutsu.stat_req_stat || "";
  statReqValueInput.value = jutsu.stat_req_value ?? "";
  jutsuBaseDamageInput.value = jutsu.base_damage ?? "";
  jutsuScalingInput.value = jutsu.scaling ?? "";
  descInput.value = jutsu.description || "";
  imageInput.value = "";
  currentImageUrl = jutsu.image_url || null;
  removeImageRequested = false;
  setPreview(currentImageUrl);
  formTitle.textContent = `Editando: ${jutsu.name}`;
  cancelBtn.style.display = "inline-block";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function renderTable() {
  const filterMastery = masteryFilterEl.value;
  const filtered = filterMastery ? allJutsus.filter((j) => j.mastery_id === filterMastery) : allJutsus;

  tbody.innerHTML = "";
  statusEl.textContent = filtered.length === 0 ? "Nenhum jutsu cadastrado." : "";

  filtered.forEach((jutsu) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><div class="item-icon-frame">${iconFrameHtml(jutsu.image_url, { empty: "—" })}</div></td>
      <td>${jutsu.name}</td>
      <td>${masteryName(jutsu.mastery_id) || "—"}</td>
      <td>${jutsu.rank || "—"}</td>
      <td>${jutsu.level_required ?? "—"}</td>
      <td>${jutsu.chakra_cost ?? "—"}</td>
      <td>${jutsu.cooldown_seconds !== null && jutsu.cooldown_seconds !== undefined ? `${jutsu.cooldown_seconds}s` : "—"}</td>
      <td style="white-space:nowrap;">
        <button type="button" class="btn btn-small" data-action="edit">Editar</button>
        <button type="button" class="btn btn-small btn-danger" data-action="delete">Excluir</button>
      </td>
    `;
    tr.querySelector('[data-action="edit"]').addEventListener("click", () => fillFormForEdit(jutsu));
    tr.querySelector('[data-action="delete"]').addEventListener("click", () => deleteJutsu(jutsu));
    tbody.appendChild(tr);
  });
}

async function loadJutsus() {
  statusEl.textContent = "Carregando...";

  const { data, error } = await supabase.from("jutsus").select("*").order("name");

  if (error) {
    statusEl.textContent = `Erro: ${error.message}`;
    return;
  }

  allJutsus = data || [];
  renderTable();
}

async function deleteJutsu(jutsu) {
  if (!confirm(`Excluir o jutsu "${jutsu.name}"?`)) return;
  const { error } = await supabase.from("jutsus").delete().eq("id", jutsu.id);
  if (error) {
    alert(`Erro ao excluir: ${error.message}`);
    return;
  }
  if (jutsu.image_url) await deleteImageFromStorage(jutsu.image_url);
  loadJutsus();
}

masteryInput.addEventListener("change", () => refreshBranchOptions(masteryInput.value));
masteryFilterEl.addEventListener("change", renderTable);

imageInput.addEventListener("change", () => {
  const file = imageInput.files[0];
  if (!file) return;
  removeImageRequested = false;
  const reader = new FileReader();
  reader.onload = () => setPreview(reader.result);
  reader.readAsDataURL(file);
});

removeImageBtn.addEventListener("click", () => {
  imageInput.value = "";
  removeImageRequested = true;
  setPreview(null);
});

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  errorEl.textContent = "";

  const payload = {
    name: nameInput.value.trim(),
    mastery_id: masteryInput.value || null,
    mastery_branch_id: branchInput.value || null,
    rank: rankInput.value || null,
    level_required: levelInput.value === "" ? null : Number(levelInput.value),
    chakra_cost: chakraInput.value === "" ? null : Number(chakraInput.value),
    cooldown_seconds: cooldownInput.value === "" ? null : Number(cooldownInput.value),
    stat_req_stat: statReqStatInput.value || null,
    stat_req_value: statReqValueInput.value === "" ? null : Number(statReqValueInput.value),
    base_damage: jutsuBaseDamageInput.value === "" ? null : Number(jutsuBaseDamageInput.value),
    scaling: jutsuScalingInput.value === "" ? null : Number(jutsuScalingInput.value),
    description: descInput.value.trim() || null,
  };

  if (!payload.name) {
    errorEl.textContent = "Informe o nome do jutsu.";
    return;
  }

  const submitBtn = form.querySelector('button[type="submit"]');
  submitBtn.disabled = true;
  submitBtn.textContent = "Salvando...";

  try {
    const newFile = imageInput.files[0];

    if (newFile) {
      payload.image_url = await uploadImage(newFile);
      if (currentImageUrl) await deleteImageFromStorage(currentImageUrl);
    } else if (removeImageRequested) {
      payload.image_url = null;
      if (currentImageUrl) await deleteImageFromStorage(currentImageUrl);
    }

    const editingId = idInput.value;
    const { error } = editingId
      ? await supabase.from("jutsus").update(payload).eq("id", editingId)
      : await supabase.from("jutsus").insert(payload);

    if (error) {
      errorEl.textContent = `Erro ao salvar: ${error.message}`;
      return;
    }

    resetForm();
    loadJutsus();
  } catch (err) {
    errorEl.textContent = err.message || "Erro ao salvar.";
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "Salvar";
  }
});

cancelBtn.addEventListener("click", resetForm);

await loadMasteryOptions();
resetForm();
loadJutsus();

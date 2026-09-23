import { ARCOS } from "../../js/config.js";
import { supabase } from "../../js/supabaseClient.js";
import { requireAuth, wireLogoutButton } from "./auth.js";
import { uploadImage, deleteImageFromStorage } from "../../js/storage-upload.js";
import {
  MOB_CATEGORY_LABELS,
  MOB_COMBAT_TYPE_LABELS,
  formatDamage,
  formatDropQuantity,
  formatDropRate,
} from "../../js/mobs-shared.js";

await requireAuth();
wireLogoutButton();

const form = document.getElementById("mob-form");
const formTitle = document.getElementById("form-title");
const idInput = document.getElementById("mob-id");
const nameInput = document.getElementById("mob-name");
const categoryInput = document.getElementById("mob-category");
const levelInput = document.getElementById("mob-level");
const descInput = document.getElementById("mob-description");
const imageInput = document.getElementById("mob-image");
const imagePreview = document.getElementById("mob-image-preview");
const removeImageBtn = document.getElementById("btn-remove-image");
const abilitiesList = document.getElementById("abilities-list");
const addAbilityBtn = document.getElementById("btn-add-ability");
const arcoInput = document.getElementById("mob-arco");
const pinInput = document.getElementById("mob-pin");
const locationNoteInput = document.getElementById("mob-location-note");
const hpInput = document.getElementById("mob-hp");
const damageMinInput = document.getElementById("mob-damage-min");
const damageMaxInput = document.getElementById("mob-damage-max");
const combatTypeInput = document.getElementById("mob-combat-type");
const xpInput = document.getElementById("mob-xp");
const dropsList = document.getElementById("drops-list");
const addDropBtn = document.getElementById("btn-add-drop");
const errorEl = document.getElementById("mob-error");
const cancelBtn = document.getElementById("btn-cancel-edit");
const statusEl = document.getElementById("mobs-status");
const tbody = document.getElementById("mobs-tbody");

let allItems = [];
let currentImageUrl = null;
let removeImageRequested = false;

function iconFrameHtml(url, { empty = "Sem imagem" } = {}) {
  return url ? `<img src="${url}" alt="" />` : `<span class="item-icon-frame__empty">${empty}</span>`;
}

function setPreview(url) {
  imagePreview.innerHTML = iconFrameHtml(url);
  removeImageBtn.style.display = url ? "inline-block" : "none";
}

function addAbilityRow(name = "") {
  const row = document.createElement("div");
  row.className = "objective-row";
  row.innerHTML = `
    <input type="text" class="ability-name" placeholder="Nome da habilidade" value="${name}" style="flex:1;" />
    <button type="button" class="btn btn-small btn-danger" title="Remover">✕</button>
  `;
  row.querySelector("button").addEventListener("click", () => row.remove());
  abilitiesList.appendChild(row);
}

function getAbilitiesFromForm() {
  return Array.from(abilitiesList.querySelectorAll(".ability-name"))
    .map((input) => input.value.trim())
    .filter(Boolean);
}

function populateArcoSelect() {
  ARCOS.forEach((arco) => {
    const option = document.createElement("option");
    option.value = arco.id;
    option.textContent = arco.label;
    arcoInput.appendChild(option);
  });
}

async function loadItems() {
  const { data, error } = await supabase.from("items").select("id, name, type").order("name");
  if (error) {
    console.error("Erro ao carregar itens:", error.message);
    return;
  }
  allItems = data || [];
}

async function refreshPinOptions(arcoId, selectedPinId = "") {
  pinInput.innerHTML = '<option value="">— Nenhum ainda —</option>';
  if (!arcoId) return;

  const { data, error } = await supabase
    .from("pins")
    .select("id, name")
    .eq("arco_id", arcoId)
    .order("name");

  if (error) {
    console.error("Erro ao carregar pins:", error.message);
    return;
  }

  (data || []).forEach((pin) => {
    const option = document.createElement("option");
    option.value = pin.id;
    option.textContent = pin.name;
    pinInput.appendChild(option);
  });

  pinInput.value = selectedPinId || "";
}

function itemOptionsHtml(selectedId) {
  if (allItems.length === 0) {
    return `<option value="">— cadastre um item primeiro —</option>`;
  }
  return allItems
    .map((i) => `<option value="${i.id}" ${i.id === selectedId ? "selected" : ""}>${i.name}</option>`)
    .join("");
}

function addDropRow(drop = {}) {
  const row = document.createElement("div");
  row.className = "objective-row";
  row.innerHTML = `
    <select class="drop-item" style="flex:2;">${itemOptionsHtml(drop.item_id)}</select>
    <input type="number" class="drop-qty-min" placeholder="Qtd min" min="1" value="${drop.quantity_min ?? 1}" style="max-width:80px;" />
    <input type="number" class="drop-qty-max" placeholder="Qtd max" min="1" value="${drop.quantity_max ?? 1}" style="max-width:80px;" />
    <input type="number" class="drop-rate" placeholder="% chance" min="0" max="100" step="0.01" value="${drop.drop_rate ?? ""}" style="max-width:90px;" />
    <button type="button" class="btn btn-small btn-danger" title="Remover">✕</button>
  `;
  row.querySelector("button").addEventListener("click", () => row.remove());
  dropsList.appendChild(row);
}

function getDropsFromForm() {
  return Array.from(dropsList.querySelectorAll(".objective-row"))
    .map((row) => {
      const item_id = row.querySelector(".drop-item").value;
      const quantity_min = Number(row.querySelector(".drop-qty-min").value) || 1;
      const quantity_max = Number(row.querySelector(".drop-qty-max").value) || quantity_min;
      const rateRaw = row.querySelector(".drop-rate").value;
      const drop_rate = rateRaw === "" ? null : Number(rateRaw);
      return { item_id, quantity_min, quantity_max, drop_rate };
    })
    .filter((d) => d.item_id);
}

async function resetForm() {
  idInput.value = "";
  nameInput.value = "";
  categoryInput.value = "regular";
  levelInput.value = 1;
  descInput.value = "";
  imageInput.value = "";
  currentImageUrl = null;
  removeImageRequested = false;
  setPreview(null);
  abilitiesList.innerHTML = "";
  addAbilityRow();
  arcoInput.value = "";
  locationNoteInput.value = "";
  hpInput.value = 1;
  damageMinInput.value = "";
  damageMaxInput.value = "";
  combatTypeInput.value = "agressivo";
  xpInput.value = 0;
  dropsList.innerHTML = "";
  addDropRow();
  errorEl.textContent = "";
  formTitle.textContent = "Novo mob";
  cancelBtn.style.display = "none";
  await refreshPinOptions("");
}

async function fillFormForEdit(mob) {
  idInput.value = mob.id;
  nameInput.value = mob.name;
  categoryInput.value = mob.category;
  levelInput.value = mob.level;
  descInput.value = mob.description || "";
  imageInput.value = "";
  currentImageUrl = mob.image_url || null;
  removeImageRequested = false;
  setPreview(currentImageUrl);
  abilitiesList.innerHTML = "";
  const abilities = mob.special_abilities || [];
  abilities.forEach((a) => addAbilityRow(a));
  if (abilities.length === 0) addAbilityRow();
  arcoInput.value = mob.arco_id || "";
  locationNoteInput.value = mob.location_note || "";
  hpInput.value = mob.hp;
  damageMinInput.value = mob.damage_min ?? "";
  damageMaxInput.value = mob.damage_max ?? "";
  combatTypeInput.value = mob.combat_type;
  xpInput.value = mob.xp_reward ?? 0;

  await refreshPinOptions(mob.arco_id, mob.pin_id);

  dropsList.innerHTML = "";
  const drops = (mob.mob_drops || []).map((d) => ({
    item_id: d.item_id,
    quantity_min: d.quantity_min,
    quantity_max: d.quantity_max,
    drop_rate: d.drop_rate,
  }));
  drops.forEach((d) => addDropRow(d));
  if (drops.length === 0) addDropRow();

  formTitle.textContent = `Editando: ${mob.name}`;
  cancelBtn.style.display = "inline-block";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function arcoLabel(arcoId) {
  const arco = ARCOS.find((a) => a.id === arcoId);
  return arco ? arco.label : "";
}

async function loadMobs() {
  statusEl.textContent = "Carregando...";
  tbody.innerHTML = "";

  const { data, error } = await supabase
    .from("mobs")
    .select("*, pins(name), mob_drops(item_id, quantity_min, quantity_max, drop_rate, items(name))")
    .order("name");

  if (error) {
    statusEl.textContent = `Erro: ${error.message}`;
    return;
  }

  statusEl.textContent = data.length === 0 ? "Nenhum mob cadastrado ainda." : "";

  data.forEach((mob) => {
    const dropsText = (mob.mob_drops || [])
      .map((d) => {
        const itemName = d.items ? d.items.name : "?";
        const rate = formatDropRate(d.drop_rate);
        return `${formatDropQuantity(d.quantity_min, d.quantity_max)} ${itemName}${rate ? ` (${rate})` : ""}`;
      })
      .join(", ") || "—";

    const locationText = mob.pins
      ? `${mob.pins.name}${mob.arco_id ? ` (${arcoLabel(mob.arco_id)})` : ""}`
      : [mob.location_note, mob.arco_id ? arcoLabel(mob.arco_id) : null].filter(Boolean).join(" · ") || "—";

    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${mob.name}</td>
      <td>${MOB_CATEGORY_LABELS[mob.category] || mob.category}</td>
      <td>${mob.level}</td>
      <td style="max-width:160px; white-space:normal;">${locationText}</td>
      <td>${mob.hp}</td>
      <td>${formatDamage(mob.damage_min, mob.damage_max)}</td>
      <td>${MOB_COMBAT_TYPE_LABELS[mob.combat_type] || mob.combat_type}</td>
      <td>${mob.xp_reward ?? 0}</td>
      <td style="max-width:220px; white-space:normal;">${dropsText}</td>
      <td style="white-space:nowrap;">
        <button type="button" class="btn btn-small" data-action="edit">Editar</button>
        <button type="button" class="btn btn-small btn-danger" data-action="delete">Excluir</button>
      </td>
    `;
    tr.querySelector('[data-action="edit"]').addEventListener("click", () => fillFormForEdit(mob));
    tr.querySelector('[data-action="delete"]').addEventListener("click", () => deleteMob(mob));
    tbody.appendChild(tr);
  });
}

async function deleteMob(mob) {
  if (!confirm(`Excluir o mob "${mob.name}"? Isso também remove os drops cadastrados dele.`)) return;
  const { error } = await supabase.from("mobs").delete().eq("id", mob.id);
  if (error) {
    alert(`Erro ao excluir: ${error.message}`);
    return;
  }
  if (mob.image_url) await deleteImageFromStorage(mob.image_url);
  loadMobs();
}

arcoInput.addEventListener("change", () => refreshPinOptions(arcoInput.value));
addDropBtn.addEventListener("click", () => addDropRow());
addAbilityBtn.addEventListener("click", () => addAbilityRow());
cancelBtn.addEventListener("click", resetForm);

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

  const damage_min = damageMinInput.value === "" ? null : Number(damageMinInput.value);
  const damage_max = damageMaxInput.value === "" ? null : Number(damageMaxInput.value);

  const payload = {
    name: nameInput.value.trim(),
    category: categoryInput.value,
    level: Number(levelInput.value) || 1,
    description: descInput.value.trim() || null,
    special_abilities: getAbilitiesFromForm(),
    arco_id: arcoInput.value || null,
    pin_id: pinInput.value || null,
    location_note: locationNoteInput.value.trim() || null,
    hp: Number(hpInput.value) || 1,
    damage_min,
    damage_max,
    combat_type: combatTypeInput.value,
    xp_reward: Number(xpInput.value) || 0,
  };

  if (!payload.name) {
    errorEl.textContent = "Informe o nome do mob.";
    return;
  }
  if (damage_min !== null && damage_max !== null && damage_min > damage_max) {
    errorEl.textContent = "O dano mínimo não pode ser maior que o dano máximo.";
    return;
  }

  const newFile = imageInput.files[0];
  if (newFile) {
    try {
      payload.image_url = await uploadImage(newFile);
      if (currentImageUrl) await deleteImageFromStorage(currentImageUrl);
    } catch (err) {
      errorEl.textContent = err.message || "Erro ao enviar imagem.";
      return;
    }
  } else if (removeImageRequested) {
    payload.image_url = null;
    if (currentImageUrl) await deleteImageFromStorage(currentImageUrl);
  }

  const drops = getDropsFromForm();
  const editingId = idInput.value;

  let mobId = editingId;
  if (editingId) {
    const { error } = await supabase.from("mobs").update(payload).eq("id", editingId);
    if (error) {
      errorEl.textContent = `Erro ao salvar: ${error.message}`;
      return;
    }
  } else {
    const { data, error } = await supabase.from("mobs").insert(payload).select("id").single();
    if (error) {
      errorEl.textContent = `Erro ao salvar: ${error.message}`;
      return;
    }
    mobId = data.id;
  }

  // Sincroniza os drops: apaga os antigos e insere os atuais do formulário.
  const { error: deleteError } = await supabase.from("mob_drops").delete().eq("mob_id", mobId);
  if (deleteError) {
    errorEl.textContent = `Mob salvo, mas houve erro ao atualizar os drops: ${deleteError.message}`;
    return;
  }

  if (drops.length > 0) {
    const dropsPayload = drops.map((d) => ({ ...d, mob_id: mobId }));
    const { error: dropsError } = await supabase.from("mob_drops").insert(dropsPayload);
    if (dropsError) {
      errorEl.textContent = `Mob salvo, mas houve erro ao salvar os drops: ${dropsError.message}`;
      return;
    }
  }

  await resetForm();
  loadMobs();
});

populateArcoSelect();
await loadItems();
await resetForm();
loadMobs();

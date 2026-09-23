import { supabase } from "../../js/supabaseClient.js";
import { requireAuth, wireLogoutButton } from "./auth.js";
import { ITEM_TYPE_LABELS } from "../../js/mobs-shared.js";
import { uploadImage, deleteImageFromStorage } from "../../js/storage-upload.js";

await requireAuth();
wireLogoutButton();

const form = document.getElementById("item-form");
const formTitle = document.getElementById("form-title");
const idInput = document.getElementById("item-id");
const nameInput = document.getElementById("item-name");
const typeInput = document.getElementById("item-type");
const descInput = document.getElementById("item-description");
const imageInput = document.getElementById("item-image");
const imagePreview = document.getElementById("item-image-preview");
const removeImageBtn = document.getElementById("btn-remove-image");
const errorEl = document.getElementById("item-error");
const cancelBtn = document.getElementById("btn-cancel-edit");
const statusEl = document.getElementById("items-status");
const tbody = document.getElementById("items-tbody");
const typeFilterEl = document.getElementById("items-type-filter");

const weaponFieldsEl = document.getElementById("weapon-fields");
const weaponCategoryInput = document.getElementById("item-weapon-category");
const weaponMasteryInput = document.getElementById("item-weapon-mastery");
const baseDamageInput = document.getElementById("item-base-damage");
const attackRangeInput = document.getElementById("item-attack-range");
const weaponGroupInput = document.getElementById("item-weapon-group");
const weaponRarityInput = document.getElementById("item-weapon-rarity");
const weaponAgiScalingInput = document.getElementById("item-weapon-agi-scaling");
const weaponRequirementsInput = document.getElementById("item-weapon-requirements");
const weaponBuffsInput = document.getElementById("item-weapon-buffs");

let allItems = [];
// image_url atual salvo no banco (pra saber se precisa apagar do storage
// quando trocar/remover a imagem), e se o usuário pediu pra remover.
let currentImageUrl = null;
let removeImageRequested = false;

function iconFrameHtml(url, { empty = "Sem imagem" } = {}) {
  return url
    ? `<img src="${url}" alt="" />`
    : `<span class="item-icon-frame__empty">${empty}</span>`;
}

function setPreview(url) {
  imagePreview.innerHTML = iconFrameHtml(url);
  removeImageBtn.style.display = url ? "inline-block" : "none";
}

function updateWeaponFieldsVisibility() {
  weaponFieldsEl.style.display = typeInput.value === "arma" ? "block" : "none";
}

async function loadWeaponMasteryOptions() {
  const { data, error } = await supabase.from("masteries").select("id, name").order("name");
  if (error) {
    console.error("Erro ao carregar maestrias:", error.message);
    return;
  }
  weaponMasteryInput.innerHTML = '<option value="">— Não definida —</option>';
  (data || []).forEach((m) => {
    const option = document.createElement("option");
    option.value = m.id;
    option.textContent = m.name;
    weaponMasteryInput.appendChild(option);
  });
}

function resetForm() {
  idInput.value = "";
  nameInput.value = "";
  typeInput.value = "item_mob";
  descInput.value = "";
  weaponCategoryInput.value = "";
  weaponMasteryInput.value = "";
  baseDamageInput.value = "";
  attackRangeInput.value = "";
  weaponGroupInput.value = "";
  weaponRarityInput.value = "";
  weaponAgiScalingInput.checked = false;
  weaponRequirementsInput.value = "";
  weaponBuffsInput.value = "";
  updateWeaponFieldsVisibility();
  imageInput.value = "";
  currentImageUrl = null;
  removeImageRequested = false;
  setPreview(null);
  errorEl.textContent = "";
  formTitle.textContent = "Novo item";
  cancelBtn.style.display = "none";
}

function fillFormForEdit(item) {
  idInput.value = item.id;
  nameInput.value = item.name;
  typeInput.value = item.type;
  descInput.value = item.description || "";
  weaponCategoryInput.value = item.weapon_category || "";
  weaponMasteryInput.value = item.weapon_mastery_id || "";
  baseDamageInput.value = item.base_damage ?? "";
  attackRangeInput.value = item.attack_range ?? "";
  weaponGroupInput.value = item.weapon_group || "";
  weaponRarityInput.value = item.weapon_rarity || "";
  weaponAgiScalingInput.checked = !!item.weapon_agi_scaling;
  weaponRequirementsInput.value = item.weapon_requirements ? JSON.stringify(item.weapon_requirements) : "";
  weaponBuffsInput.value = item.weapon_buffs ? JSON.stringify(item.weapon_buffs) : "";
  updateWeaponFieldsVisibility();
  imageInput.value = "";
  currentImageUrl = item.image_url || null;
  removeImageRequested = false;
  setPreview(currentImageUrl);
  formTitle.textContent = `Editando: ${item.name}`;
  cancelBtn.style.display = "inline-block";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function renderTable() {
  const typeFilter = typeFilterEl.value;
  const filtered = typeFilter ? allItems.filter((i) => i.type === typeFilter) : allItems;

  tbody.innerHTML = "";
  statusEl.textContent = filtered.length === 0 ? "Nenhum item cadastrado." : "";

  filtered.forEach((item) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><div class="item-icon-frame">${iconFrameHtml(item.image_url, { empty: "—" })}</div></td>
      <td>${item.name}</td>
      <td>${ITEM_TYPE_LABELS[item.type] || item.type}</td>
      <td>${item.description || ""}</td>
      <td style="white-space:nowrap;">
        <button type="button" class="btn btn-small" data-action="edit">Editar</button>
        <button type="button" class="btn btn-small btn-danger" data-action="delete">Excluir</button>
      </td>
    `;
    tr.querySelector('[data-action="edit"]').addEventListener("click", () => fillFormForEdit(item));
    tr.querySelector('[data-action="delete"]').addEventListener("click", () => deleteItem(item));
    tbody.appendChild(tr);
  });
}

async function loadItems() {
  statusEl.textContent = "Carregando...";

  const { data, error } = await supabase.from("items").select("*").order("name");

  if (error) {
    statusEl.textContent = `Erro: ${error.message}`;
    return;
  }

  allItems = data || [];
  renderTable();
}

async function deleteItem(item) {
  if (!confirm(`Excluir o item "${item.name}"? Isso também remove os drops ligados a ele.`)) return;
  const { error } = await supabase.from("items").delete().eq("id", item.id);
  if (error) {
    alert(`Erro ao excluir: ${error.message}`);
    return;
  }
  if (item.image_url) await deleteImageFromStorage(item.image_url);
  loadItems();
}

typeInput.addEventListener("change", updateWeaponFieldsVisibility);

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

  const isWeapon = typeInput.value === "arma";

  let weaponRequirements = null;
  let weaponBuffs = null;
  if (isWeapon) {
    try {
      weaponRequirements = weaponRequirementsInput.value.trim() ? JSON.parse(weaponRequirementsInput.value) : null;
      weaponBuffs = weaponBuffsInput.value.trim() ? JSON.parse(weaponBuffsInput.value) : null;
    } catch {
      errorEl.textContent = "Requisitos/bônus da arma precisam ser um JSON válido (ex: {\"Level\": 10}).";
      return;
    }
  }

  const payload = {
    name: nameInput.value.trim(),
    type: typeInput.value,
    description: descInput.value.trim() || null,
    weapon_category: isWeapon ? weaponCategoryInput.value || null : null,
    weapon_mastery_id: isWeapon ? weaponMasteryInput.value || null : null,
    base_damage: isWeapon && baseDamageInput.value !== "" ? Number(baseDamageInput.value) : null,
    attack_range: isWeapon && attackRangeInput.value !== "" ? Number(attackRangeInput.value) : null,
    weapon_group: isWeapon ? weaponGroupInput.value || null : null,
    weapon_rarity: isWeapon ? weaponRarityInput.value.trim() || null : null,
    weapon_agi_scaling: isWeapon ? weaponAgiScalingInput.checked : false,
    weapon_requirements: weaponRequirements,
    weapon_buffs: weaponBuffs,
  };

  if (!payload.name) {
    errorEl.textContent = "Informe o nome do item.";
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
      ? await supabase.from("items").update(payload).eq("id", editingId)
      : await supabase.from("items").insert(payload);

    if (error) {
      errorEl.textContent = `Erro ao salvar: ${error.message}`;
      return;
    }

    resetForm();
    loadItems();
  } catch (err) {
    errorEl.textContent = err.message || "Erro ao salvar.";
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "Salvar";
  }
});

cancelBtn.addEventListener("click", resetForm);
typeFilterEl.addEventListener("change", renderTable);

await loadWeaponMasteryOptions();
resetForm();
loadItems();

import { ARCOS } from "../../js/config.js";
import { supabase } from "../../js/supabaseClient.js";
import { requireAuth, wireLogoutButton } from "./auth.js";
import { uploadImage, deleteImageFromStorage } from "../../js/storage-upload.js";
import { NPC_ROLE_LABELS } from "../../js/npcs-shared.js";

await requireAuth();
wireLogoutButton();

const form = document.getElementById("npc-form");
const formTitle = document.getElementById("form-title");
const idInput = document.getElementById("npc-id");
const nameInput = document.getElementById("npc-name");
const roleCheckboxes = Array.from(document.querySelectorAll(".npc-role-checkbox"));
const descInput = document.getElementById("npc-description");
const imageInput = document.getElementById("npc-image");
const imagePreview = document.getElementById("npc-image-preview");
const removeImageBtn = document.getElementById("btn-remove-image");
const arcoInput = document.getElementById("npc-arco");
const pinInput = document.getElementById("npc-pin");
const locationNoteInput = document.getElementById("npc-location-note");
const shopItemsList = document.getElementById("shop-items-list");
const addShopItemBtn = document.getElementById("btn-add-shop-item");
const errorEl = document.getElementById("npc-error");
const cancelBtn = document.getElementById("btn-cancel-edit");
const statusEl = document.getElementById("npcs-status");
const tbody = document.getElementById("npcs-tbody");

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

function addShopItemRow(entry = {}) {
  const row = document.createElement("div");
  row.className = "objective-row";
  row.innerHTML = `
    <select class="shop-item-select" style="flex:2;">${itemOptionsHtml(entry.item_id)}</select>
    <input type="number" class="shop-item-price" placeholder="Preço (ryo)" min="0" value="${entry.price ?? 0}" style="max-width:110px;" />
    <input type="number" class="shop-item-stock" placeholder="Estoque" min="0" value="${entry.stock ?? ""}" style="max-width:90px;" />
    <button type="button" class="btn btn-small btn-danger" title="Remover">✕</button>
  `;
  row.querySelector("button").addEventListener("click", () => row.remove());
  shopItemsList.appendChild(row);
}

function getShopItemsFromForm() {
  return Array.from(shopItemsList.querySelectorAll(".objective-row"))
    .map((row) => {
      const item_id = row.querySelector(".shop-item-select").value;
      const price = Number(row.querySelector(".shop-item-price").value) || 0;
      const stockRaw = row.querySelector(".shop-item-stock").value;
      const stock = stockRaw === "" ? null : Number(stockRaw);
      return { item_id, price, stock };
    })
    .filter((s) => s.item_id);
}

function getRolesFromForm() {
  return roleCheckboxes.filter((cb) => cb.checked).map((cb) => cb.value);
}

async function resetForm() {
  idInput.value = "";
  nameInput.value = "";
  roleCheckboxes.forEach((cb) => (cb.checked = false));
  descInput.value = "";
  imageInput.value = "";
  currentImageUrl = null;
  removeImageRequested = false;
  setPreview(null);
  arcoInput.value = "";
  locationNoteInput.value = "";
  shopItemsList.innerHTML = "";
  addShopItemRow();
  errorEl.textContent = "";
  formTitle.textContent = "Novo NPC";
  cancelBtn.style.display = "none";
  await refreshPinOptions("");
}

async function fillFormForEdit(npc) {
  idInput.value = npc.id;
  nameInput.value = npc.name;
  roleCheckboxes.forEach((cb) => (cb.checked = (npc.roles || []).includes(cb.value)));
  descInput.value = npc.description || "";
  imageInput.value = "";
  currentImageUrl = npc.image_url || null;
  removeImageRequested = false;
  setPreview(currentImageUrl);
  arcoInput.value = npc.arco_id || "";
  locationNoteInput.value = npc.location_note || "";

  await refreshPinOptions(npc.arco_id, npc.pin_id);

  shopItemsList.innerHTML = "";
  const shopItems = (npc.npc_shop_items || []).map((s) => ({
    item_id: s.item_id,
    price: s.price,
    stock: s.stock,
  }));
  shopItems.forEach((s) => addShopItemRow(s));
  if (shopItems.length === 0) addShopItemRow();

  formTitle.textContent = `Editando: ${npc.name}`;
  cancelBtn.style.display = "inline-block";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function arcoLabel(arcoId) {
  const arco = ARCOS.find((a) => a.id === arcoId);
  return arco ? arco.label : "";
}

async function loadNpcs() {
  statusEl.textContent = "Carregando...";
  tbody.innerHTML = "";

  const { data, error } = await supabase
    .from("npcs")
    .select("*, pins(name), npc_shop_items(item_id, price, stock, items(name))")
    .order("name");

  if (error) {
    statusEl.textContent = `Erro: ${error.message}`;
    return;
  }

  statusEl.textContent = data.length === 0 ? "Nenhum NPC cadastrado ainda." : "";

  data.forEach((npc) => {
    const rolesText = (npc.roles || []).map((r) => NPC_ROLE_LABELS[r] || r).join(", ") || "—";

    const locationText = npc.pins
      ? `${npc.pins.name}${npc.arco_id ? ` (${arcoLabel(npc.arco_id)})` : ""}`
      : [npc.location_note, npc.arco_id ? arcoLabel(npc.arco_id) : null].filter(Boolean).join(" · ") || "—";

    const shopText =
      (npc.npc_shop_items || [])
        .map((s) => `${s.items ? s.items.name : "?"} (${s.price} ryo)`)
        .join(", ") || "—";

    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><div class="item-icon-frame">${iconFrameHtml(npc.image_url, { empty: "—" })}</div></td>
      <td>${npc.name}</td>
      <td>${rolesText}</td>
      <td style="max-width:160px; white-space:normal;">${locationText}</td>
      <td style="max-width:220px; white-space:normal;">${shopText}</td>
      <td style="white-space:nowrap;">
        <button type="button" class="btn btn-small" data-action="edit">Editar</button>
        <button type="button" class="btn btn-small btn-danger" data-action="delete">Excluir</button>
      </td>
    `;
    tr.querySelector('[data-action="edit"]').addEventListener("click", () => fillFormForEdit(npc));
    tr.querySelector('[data-action="delete"]').addEventListener("click", () => deleteNpc(npc));
    tbody.appendChild(tr);
  });
}

async function deleteNpc(npc) {
  if (!confirm(`Excluir o NPC "${npc.name}"? Isso também remove os itens à venda ligados a ele e desvincula missões que ele concedia.`)) return;
  const { error } = await supabase.from("npcs").delete().eq("id", npc.id);
  if (error) {
    alert(`Erro ao excluir: ${error.message}`);
    return;
  }
  if (npc.image_url) await deleteImageFromStorage(npc.image_url);
  loadNpcs();
}

arcoInput.addEventListener("change", () => refreshPinOptions(arcoInput.value));
addShopItemBtn.addEventListener("click", () => addShopItemRow());
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

  const payload = {
    name: nameInput.value.trim(),
    roles: getRolesFromForm(),
    description: descInput.value.trim() || null,
    arco_id: arcoInput.value || null,
    pin_id: pinInput.value || null,
    location_note: locationNoteInput.value.trim() || null,
  };

  if (!payload.name) {
    errorEl.textContent = "Informe o nome do NPC.";
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

  const shopItems = getShopItemsFromForm();
  const editingId = idInput.value;

  let npcId = editingId;
  if (editingId) {
    const { error } = await supabase.from("npcs").update(payload).eq("id", editingId);
    if (error) {
      errorEl.textContent = `Erro ao salvar: ${error.message}`;
      return;
    }
  } else {
    const { data, error } = await supabase.from("npcs").insert(payload).select("id").single();
    if (error) {
      errorEl.textContent = `Erro ao salvar: ${error.message}`;
      return;
    }
    npcId = data.id;
  }

  // Sincroniza os itens à venda: apaga os antigos e insere os atuais do formulário.
  const { error: deleteError } = await supabase.from("npc_shop_items").delete().eq("npc_id", npcId);
  if (deleteError) {
    errorEl.textContent = `NPC salvo, mas houve erro ao atualizar os itens à venda: ${deleteError.message}`;
    return;
  }

  if (shopItems.length > 0) {
    const shopPayload = shopItems.map((s) => ({ ...s, npc_id: npcId }));
    const { error: shopError } = await supabase.from("npc_shop_items").insert(shopPayload);
    if (shopError) {
      errorEl.textContent = `NPC salvo, mas houve erro ao salvar os itens à venda: ${shopError.message}`;
      return;
    }
  }

  await resetForm();
  loadNpcs();
});

populateArcoSelect();
await loadItems();
await resetForm();
loadNpcs();

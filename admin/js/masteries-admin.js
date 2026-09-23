import { supabase } from "../../js/supabaseClient.js";
import { requireAuth, wireLogoutButton } from "./auth.js";
import { uploadImage, deleteImageFromStorage } from "../../js/storage-upload.js";

await requireAuth();
wireLogoutButton();

const form = document.getElementById("mastery-form");
const formTitle = document.getElementById("form-title");
const idInput = document.getElementById("mastery-id");
const slugInput = document.getElementById("mastery-slug");
const nameInput = document.getElementById("mastery-name");
const descInput = document.getElementById("mastery-description");
const playstyleInput = document.getElementById("mastery-playstyle");
const imageInput = document.getElementById("mastery-image");
const imagePreview = document.getElementById("mastery-image-preview");
const removeImageBtn = document.getElementById("btn-remove-image");
const branchesList = document.getElementById("branches-list");
const btnAddBranch = document.getElementById("btn-add-branch");
const errorEl = document.getElementById("mastery-error");
const cancelBtn = document.getElementById("btn-cancel-edit");
const statusEl = document.getElementById("masteries-status");
const tbody = document.getElementById("masteries-tbody");

let allMasteries = [];
let currentImageUrl = null;
let removeImageRequested = false;

function iconFrameHtml(url, { empty = "Sem imagem" } = {}) {
  return url ? `<img src="${url}" alt="" />` : `<span class="item-icon-frame__empty">${empty}</span>`;
}

function setPreview(url) {
  imagePreview.innerHTML = iconFrameHtml(url);
  removeImageBtn.style.display = url ? "inline-block" : "none";
}

function addBranchRow(branch = {}) {
  const row = document.createElement("div");
  row.className = "objective-row";
  row.innerHTML = `
    <input type="text" class="branch-name" placeholder="Nome da ramificação" value="${branch.name || ""}" />
    <input type="text" class="branch-description" placeholder="Descrição (opcional)" value="${branch.description || ""}" />
    <button type="button" class="btn btn-small btn-danger">Remover</button>
  `;
  row.querySelector("button").addEventListener("click", () => row.remove());
  branchesList.appendChild(row);
}

function getBranchesFromForm() {
  return Array.from(branchesList.querySelectorAll(".objective-row"))
    .map((row) => ({
      name: row.querySelector(".branch-name").value.trim(),
      description: row.querySelector(".branch-description").value.trim() || null,
    }))
    .filter((b) => b.name);
}

function resetForm() {
  idInput.value = "";
  slugInput.value = "";
  nameInput.value = "";
  descInput.value = "";
  playstyleInput.value = "";
  imageInput.value = "";
  currentImageUrl = null;
  removeImageRequested = false;
  setPreview(null);
  branchesList.innerHTML = "";
  errorEl.textContent = "";
  formTitle.textContent = "Nova maestria";
  cancelBtn.style.display = "none";
}

function fillFormForEdit(mastery) {
  idInput.value = mastery.id;
  slugInput.value = mastery.slug;
  nameInput.value = mastery.name;
  descInput.value = mastery.description || "";
  playstyleInput.value = mastery.playstyle_notes || "";
  imageInput.value = "";
  currentImageUrl = mastery.image_url || null;
  removeImageRequested = false;
  setPreview(currentImageUrl);
  branchesList.innerHTML = "";
  (mastery.mastery_branches || []).forEach((b) => addBranchRow(b));
  formTitle.textContent = `Editando: ${mastery.name}`;
  cancelBtn.style.display = "inline-block";
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function renderTable() {
  tbody.innerHTML = "";
  statusEl.textContent = allMasteries.length === 0 ? "Nenhuma maestria cadastrada." : "";

  allMasteries.forEach((mastery) => {
    const branchNames = (mastery.mastery_branches || []).map((b) => b.name).join(", ");
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><div class="item-icon-frame">${iconFrameHtml(mastery.image_url, { empty: "—" })}</div></td>
      <td>${mastery.name}</td>
      <td>${mastery.slug}</td>
      <td>${branchNames || "—"}</td>
      <td style="white-space:nowrap;">
        <button type="button" class="btn btn-small" data-action="edit">Editar</button>
        <button type="button" class="btn btn-small btn-danger" data-action="delete">Excluir</button>
      </td>
    `;
    tr.querySelector('[data-action="edit"]').addEventListener("click", () => fillFormForEdit(mastery));
    tr.querySelector('[data-action="delete"]').addEventListener("click", () => deleteMastery(mastery));
    tbody.appendChild(tr);
  });
}

async function loadMasteries() {
  statusEl.textContent = "Carregando...";

  const { data, error } = await supabase
    .from("masteries")
    .select("*, mastery_branches(id, name, description)")
    .order("name");

  if (error) {
    statusEl.textContent = `Erro: ${error.message}`;
    return;
  }

  allMasteries = data || [];
  renderTable();
}

async function deleteMastery(mastery) {
  if (
    !confirm(
      `Excluir a maestria "${mastery.name}"? Isso também remove as ramificações dela, e jutsus ligados a ela ficam sem maestria definida.`
    )
  )
    return;
  const { error } = await supabase.from("masteries").delete().eq("id", mastery.id);
  if (error) {
    alert(`Erro ao excluir: ${error.message}`);
    return;
  }
  if (mastery.image_url) await deleteImageFromStorage(mastery.image_url);
  loadMasteries();
}

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

btnAddBranch.addEventListener("click", () => addBranchRow());

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  errorEl.textContent = "";

  const payload = {
    slug: slugInput.value.trim(),
    name: nameInput.value.trim(),
    description: descInput.value.trim() || null,
    playstyle_notes: playstyleInput.value.trim() || null,
  };

  if (!payload.slug || !payload.name) {
    errorEl.textContent = "Informe o slug e o nome da maestria.";
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
    let masteryId = editingId;

    if (editingId) {
      const { error } = await supabase.from("masteries").update(payload).eq("id", editingId);
      if (error) throw new Error(error.message);
    } else {
      const { data, error } = await supabase.from("masteries").insert(payload).select("id").single();
      if (error) throw new Error(error.message);
      masteryId = data.id;
    }

    // Sincroniza as ramificações: apaga as antigas e insere as do formulário
    // (mesmo padrão usado nos drops de mob e nos itens à venda de NPC).
    const { error: deleteBranchesError } = await supabase
      .from("mastery_branches")
      .delete()
      .eq("mastery_id", masteryId);
    if (deleteBranchesError) throw new Error(deleteBranchesError.message);

    const branches = getBranchesFromForm();
    if (branches.length > 0) {
      const { error: insertBranchesError } = await supabase
        .from("mastery_branches")
        .insert(branches.map((b) => ({ ...b, mastery_id: masteryId })));
      if (insertBranchesError) throw new Error(insertBranchesError.message);
    }

    resetForm();
    loadMasteries();
  } catch (err) {
    errorEl.textContent = err.message || "Erro ao salvar.";
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = "Salvar";
  }
});

cancelBtn.addEventListener("click", resetForm);

resetForm();
loadMasteries();

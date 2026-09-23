import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations } from "./i18n.js";
import { itemTypeLabelI18n, weaponCategoryLabelI18n } from "./mobs-shared.js";

const statusEl = document.getElementById("items-status");
const tbody = document.getElementById("items-tbody");
const filterTypeEl = document.getElementById("filter-type");
const searchEl = document.getElementById("search-items");

let allItems = [];
let statusKind = null;

function normalize(str) {
  return (str || "")
    .toString()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

function renderItems() {
  const typeFilter = filterTypeEl.value;
  const searchTerm = normalize(searchEl.value);

  const filtered = allItems.filter((i) => {
    if (typeFilter && i.type !== typeFilter) return false;
    if (searchTerm && !normalize(i.name).includes(searchTerm) && !normalize(i.description).includes(searchTerm)) {
      return false;
    }
    return true;
  });

  tbody.innerHTML = "";

  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="7">${t("items_none")}</td></tr>`;
    return;
  }

  filtered.forEach((item) => {
    const droppedBy = (item.mob_drops || [])
      .map((d) => (d.mobs ? d.mobs.name : null))
      .filter(Boolean)
      .join(", ");

    const iconInner = item.image_url
      ? `<img src="${item.image_url}" alt="" />`
      : `<span class="item-icon-frame__empty">—</span>`;

    const isWeapon = item.type === "arma";
    const typeLabel = isWeapon && item.weapon_category
      ? `${itemTypeLabelI18n(item.type)} (${weaponCategoryLabelI18n(item.weapon_category)})`
      : itemTypeLabelI18n(item.type);
    const damage = isWeapon && item.base_damage !== null && item.base_damage !== undefined ? item.base_damage : "—";
    const range = isWeapon && item.attack_range !== null && item.attack_range !== undefined ? item.attack_range : "—";

    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td><div class="item-icon-frame">${iconInner}</div></td>
      <td>${item.name}</td>
      <td>${typeLabel}</td>
      <td>${item.description || ""}</td>
      <td>${droppedBy || "—"}</td>
      <td>${damage}</td>
      <td>${range}</td>
    `;
    tbody.appendChild(tr);
  });
}

function renderStatus() {
  if (statusKind === "loading") statusEl.textContent = t("items_loading");
  else if (statusKind === "supabase-off") statusEl.textContent = t("items_supabase_off");
  else if (statusKind && statusKind.startsWith("error:")) {
    statusEl.textContent = t("items_error", { msg: statusKind.slice(6) });
  } else {
    statusEl.textContent = "";
  }
}

async function loadItems() {
  if (!isSupabaseConfigured) {
    statusKind = "supabase-off";
    renderStatus();
    return;
  }

  statusKind = "loading";
  renderStatus();

  const { data, error } = await supabase
    .from("items")
    .select("*, mob_drops(mobs(name))")
    .order("name");

  if (error) {
    statusKind = `error:${error.message}`;
    renderStatus();
    return;
  }

  allItems = data || [];
  statusKind = null;
  renderStatus();
  renderItems();
}

mountGlobalControls();
applyStaticTranslations();

filterTypeEl.addEventListener("change", renderItems);
searchEl.addEventListener("input", renderItems);

window.addEventListener("ninmap:langchange", () => {
  renderStatus();
  renderItems();
});

loadItems();

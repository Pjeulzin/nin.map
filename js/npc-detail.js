import { ARCOS } from "./config.js";
import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations, pickLabel } from "./i18n.js";
import { npcRoleLabelI18n, formatNpcLocationI18n } from "./npcs-shared.js";

const statusEl = document.getElementById("npc-status");
const detailEl = document.getElementById("npc-detail");

const npcId = new URLSearchParams(window.location.search).get("id");

let npc = null;

function arcoLabel(arcoId) {
  const arco = ARCOS.find((a) => a.id === arcoId);
  return arco ? pickLabel(arco) : arcoId;
}

function locationText(n) {
  const pinName = n.pins && n.pins.name ? n.pins.name : null;
  return formatNpcLocationI18n(n, {
    arcoLabel: n.arco_id ? arcoLabel(n.arco_id) : null,
    pinName,
  });
}

function render() {
  if (!npc) return;

  const rolesHtml = (npc.roles || [])
    .map((r) => `<span class="mission-card__tag">${npcRoleLabelI18n(r)}</span>`)
    .join("");

  const iconHtml = npc.image_url
    ? `<img src="${npc.image_url}" alt="" />`
    : `<span class="item-icon-frame__empty">—</span>`;

  const shopItems = npc.npc_shop_items || [];
  const shopHtml =
    shopItems.length > 0
      ? `
        <table class="detail-table">
          <thead>
            <tr>
              <th>${t("detail_col_item")}</th>
              <th>${t("detail_col_price")}</th>
              <th>${t("detail_col_stock")}</th>
            </tr>
          </thead>
          <tbody>
            ${shopItems
              .map((s) => {
                const itemName = s.items ? s.items.name : "?";
                const stockText = s.stock === null || s.stock === undefined ? t("stock_unlimited") : s.stock;
                return `<tr><td>${itemName}</td><td>${s.price} ryo</td><td>${stockText}</td></tr>`;
              })
              .join("")}
          </tbody>
        </table>
      `
      : `<p class="detail-empty">—</p>`;

  const missions = npc.missions || [];
  const missionsHtml =
    missions.length > 0
      ? `<ul class="detail-ability-list">${missions.map((m) => `<li>${m.name}</li>`).join("")}</ul>`
      : `<p class="detail-empty">—</p>`;

  document.title = `${npc.name} — Nin.Map`;

  detailEl.innerHTML = `
    <div class="detail-hero">
      <div class="item-icon-frame detail-hero__icon">${iconHtml}</div>
      <div class="detail-hero__body">
        <div class="detail-hero__title-row">
          <h1 class="detail-hero__title">${npc.name}</h1>
          <div class="detail-hero__tags">${rolesHtml}</div>
        </div>
        <p class="detail-hero__location">${locationText(npc)}</p>
      </div>
    </div>

    ${
      npc.description
        ? `<div class="detail-section" style="margin-bottom:16px;"><h2>${t("detail_section_about")}</h2><p>${npc.description}</p></div>`
        : ""
    }

    <div class="detail-grid">
      <div class="detail-section">
        <h2>${t("detail_section_sells")}</h2>
        ${shopHtml}
      </div>

      <div class="detail-section">
        <h2>${t("detail_section_missions")}</h2>
        ${missionsHtml}
      </div>
    </div>
  `;
}

function renderStatus() {
  if (!npcId) {
    statusEl.textContent = t("detail_not_found");
    return;
  }
  if (!isSupabaseConfigured) {
    statusEl.textContent = t("npcs_supabase_off");
    return;
  }
  if (!npc) {
    statusEl.textContent = t("detail_loading");
    return;
  }
  statusEl.textContent = "";
}

async function load() {
  renderStatus();
  if (!npcId || !isSupabaseConfigured) return;

  const { data, error } = await supabase
    .from("npcs")
    .select("*, pins(name), npc_shop_items(price, stock, items(name)), missions(name)")
    .eq("id", npcId)
    .maybeSingle();

  if (error || !data) {
    statusEl.textContent = error ? t("npcs_error", { msg: error.message }) : t("detail_not_found");
    return;
  }

  npc = data;
  renderStatus();
  render();
}

mountGlobalControls();
applyStaticTranslations();

window.addEventListener("ninmap:langchange", () => {
  renderStatus();
  render();
});

load();

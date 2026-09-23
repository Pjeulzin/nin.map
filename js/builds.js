/**
 * Calculador de build — mesma lógica de jogo do ninforge.xyz:
 * maestrias, arma (com requisitos e bônus), 5 atributos (com pool de
 * pontos por nível), vida/chakra/ataques derivados, 2 anéis (5 slots
 * de bônus cada) e jutsus com requisito de nível/atributo.
 *
 * Os dados de armas e jutsus (nomes, requisitos, dano, escala) vêm do
 * Supabase (tabelas `items` tipo 'arma' e `jutsus`, ver migração 008)
 * — foram extraídos do próprio ninforge.xyz. As fórmulas de status
 * (vida, chakra, ataques, ponto de atributo por nível) foram
 * decompiladas do código-fonte público do ninforge.xyz.
 */
import { supabase, isSupabaseConfigured } from "./supabaseClient.js";
import { mountGlobalControls } from "./chrome.js";
import { t, applyStaticTranslations } from "./i18n.js";

const STAT_KEYS = ["str", "for", "int", "agi", "cha"];
const STAT_LABELS = { str: "STR", for: "FORT", int: "INT", agi: "AGI", cha: "CHK" };
const STAT_FULL_LABELS = {
  str: "Strength",
  for: "Fortitude",
  int: "Intellect",
  agi: "Agility",
  cha: "Chakra",
};
const REQ_STAT_MAP = { Strength: "str", Fortitude: "for", Intellect: "int", Agility: "agi", Chakra: "cha" };
const BASE_STAT = 5;
const LOCAL_STORAGE_KEY = "ninmap:builds";

function emptyRingSlots() {
  return [0, 1, 2, 3, 4].map(() => ({ stat: "", value: 0 }));
}

function defaultState() {
  return {
    name: "Meu Ninja",
    level: 70,
    village: "",
    masteryId1: "",
    masteryId2: "",
    corp: "",
    guildBuff: 0,
    weaponGroup: "",
    weaponId: "",
    baseStats: { str: 5, for: 5, int: 5, agi: 5, cha: 5 },
    ring1: emptyRingSlots(),
    ring2: emptyRingSlots(),
  };
}

let state = defaultState();
let statusKind = "loading";
let masteries = [];
let weapons = [];
let jutsusByMasteryId = {};
let activeJutsuMasteryId = "";

const statusEl = document.getElementById("builds-status");
const appEl = document.getElementById("builds-app");

// ---------------------------------------------------------------
// Fórmulas do jogo (extraídas do ninforge.xyz)
// ---------------------------------------------------------------

function pointPool(level) {
  if (level <= 1) return 0;
  const e = (Math.min(level, 50) - 1) * 5;
  const tier60 = level > 50 ? (Math.min(level, 60) - 50) * 4 : 0;
  const tier70 = level > 60 ? (Math.min(level, 70) - 60) * 3 : 0;
  return e + tier60 + tier70;
}

function selectedWeapon() {
  return weapons.find((w) => w.id === state.weaponId) || null;
}

function weaponBuffStatBonus() {
  const out = { str: 0, for: 0, int: 0, agi: 0, cha: 0 };
  const w = selectedWeapon();
  if (!w || !w.weapon_buffs) return out;
  for (const [key, val] of Object.entries(w.weapon_buffs)) {
    const statKey = REQ_STAT_MAP[key];
    if (!statKey || typeof val !== "string") continue;
    const m = /^([+-]\d+)$/.exec(val.trim());
    if (m) out[statKey] += parseInt(m[1], 10);
  }
  return out;
}

function ringStatBonus() {
  const out = { str: 0, for: 0, int: 0, agi: 0, cha: 0 };
  [...state.ring1, ...state.ring2].forEach((slot) => {
    if (slot.stat && out[slot.stat] !== undefined) {
      out[slot.stat] += Number(slot.value) || 0;
    }
  });
  return out;
}

function guildBuffBonus() {
  const out = { str: 0, for: 0, int: 0, agi: 0, cha: 0 };
  if (state.guildBuff > 0) {
    STAT_KEYS.forEach((k) => {
      out[k] = Math.floor(state.baseStats[k] * (state.guildBuff / 100));
    });
  }
  return out;
}

function totalStats() {
  const weaponBonus = weaponBuffStatBonus();
  const ringBonus = ringStatBonus();
  const guildBonus = guildBuffBonus();
  const out = {};
  STAT_KEYS.forEach((k) => {
    out[k] = state.baseStats[k] + weaponBonus[k] + ringBonus[k] + guildBonus[k];
  });
  return out;
}

function computeVitals(total) {
  const hp = 210 + total.for * 8;
  const chakra = 25 + total.cha * 5;
  const kunai = 20 + Math.floor(total.str * 0.5);
  const shuriken = 20 + Math.floor(total.int * 0.5);
  const senbon = 20 + Math.floor(total.cha * 0.5);

  const weapon = selectedWeapon();
  let autoAtk;
  if (!weapon) {
    const base = 5 + Math.floor(state.level / 3);
    autoAtk = base + Math.floor((total.agi - BASE_STAT) * 0.2);
  } else if (weapon.weapon_group === "Fan") {
    const buffs = weapon.weapon_buffs || {};
    const twinProjectile = /Twin Projectile/i.test(buffs.Bonus || "");
    autoAtk = (weapon.base_damage || 0) + Math.floor(total.str * 0.18) + 4 - (twinProjectile ? 6 : 0);
  } else {
    const scaleStat = weapon.weapon_agi_scaling ? total.agi : total.str;
    autoAtk = 23 + (weapon.base_damage || 0) + Math.floor(scaleStat * 0.2);
  }
  return { hp, chakra, kunai, shuriken, senbon, autoAtk };
}

function weaponUnmetRequirements(weapon, total) {
  const unmet = [];
  if (!weapon || !weapon.weapon_requirements) return unmet;
  for (const [key, val] of Object.entries(weapon.weapon_requirements)) {
    if (key === "Level") {
      if (state.level < val) unmet.push(`Level ${val}`);
      continue;
    }
    const statKey = REQ_STAT_MAP[key];
    if (statKey && total[statKey] < val) unmet.push(`${key} ${val}`);
  }
  return unmet;
}

function jutsuDamage(j, total) {
  const statVal = j.stat_req_stat ? total[j.stat_req_stat] || 0 : 0;
  return Math.floor((j.base_damage || 0) + (j.scaling || 0) * statVal);
}

function jutsuLocked(j, total) {
  if (state.level < j.level_required) return true;
  const statVal = j.stat_req_stat ? total[j.stat_req_stat] || 0 : 0;
  return statVal < j.stat_req_value;
}

// ---------------------------------------------------------------
// Carregamento de dados
// ---------------------------------------------------------------

function renderStatus() {
  if (statusKind === "loading") statusEl.textContent = t("builds_loading");
  else if (statusKind === "supabase-off") statusEl.textContent = t("builds_supabase_off");
  else if (statusKind && statusKind.startsWith("error:")) {
    statusEl.textContent = t("builds_error", { msg: statusKind.slice(6) });
  } else {
    statusEl.textContent = "";
  }
  appEl.style.display = statusKind ? "none" : "grid";
}

async function loadData() {
  if (!isSupabaseConfigured) {
    statusKind = "supabase-off";
    renderStatus();
    return false;
  }

  statusKind = "loading";
  renderStatus();

  const [masteriesRes, weaponsRes, jutsusRes] = await Promise.all([
    supabase.from("masteries").select("id, slug, name, external_key").order("name"),
    supabase
      .from("items")
      .select("id, name, description, image_url, base_damage, attack_range, weapon_group, weapon_requirements, weapon_buffs, weapon_rarity, weapon_agi_scaling")
      .eq("type", "arma")
      .not("weapon_group", "is", null)
      .order("weapon_group")
      .order("name"),
    supabase
      .from("jutsus")
      .select("id, name, mastery_id, level_required, stat_req_stat, stat_req_value, base_damage, scaling, image_url")
      .order("level_required"),
  ]);

  const err = masteriesRes.error || weaponsRes.error || jutsusRes.error;
  if (err) {
    statusKind = `error:${err.message}`;
    renderStatus();
    return false;
  }

  masteries = masteriesRes.data || [];
  weapons = weaponsRes.data || [];
  jutsusByMasteryId = {};
  (jutsusRes.data || []).forEach((j) => {
    if (!j.mastery_id) return;
    (jutsusByMasteryId[j.mastery_id] ||= []).push(j);
  });

  statusKind = null;
  renderStatus();
  return true;
}

// ---------------------------------------------------------------
// Persistência (localStorage) e compartilhamento (URL)
// ---------------------------------------------------------------

function loadSavedBuilds() {
  try {
    const raw = localStorage.getItem(LOCAL_STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function saveSavedBuilds(list) {
  try {
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(list));
  } catch {
    /* ignore quota/storage errors */
  }
}

function encodeStateForShare() {
  try {
    return btoa(unescape(encodeURIComponent(JSON.stringify(state))));
  } catch {
    return "";
  }
}

function decodeStateFromShare(encoded) {
  try {
    return JSON.parse(decodeURIComponent(escape(atob(encoded))));
  } catch {
    return null;
  }
}

function loadStateFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const b = params.get("b");
  if (!b) return false;
  const decoded = decodeStateFromShare(b);
  if (!decoded) return false;
  state = { ...defaultState(), ...decoded };
  return true;
}

// ---------------------------------------------------------------
// Elementos
// ---------------------------------------------------------------

const el = {
  name: document.getElementById("b-name"),
  level: document.getElementById("b-level"),
  village: document.getElementById("b-village"),
  mastery1: document.getElementById("b-mastery1"),
  mastery2: document.getElementById("b-mastery2"),
  corp: document.getElementById("b-corp"),
  guildBuff: document.getElementById("b-guildbuff"),
  guildBuffValue: document.getElementById("b-guildbuff-value"),
  reset: document.getElementById("b-reset"),
  weaponGroup: document.getElementById("b-weapon-group"),
  weaponModel: document.getElementById("b-weapon-model"),
  weaponDetails: document.getElementById("b-weapon-details"),
  pointsLeft: document.getElementById("b-points-left"),
  stats: document.getElementById("b-stats"),
  hp: document.getElementById("b-hp"),
  chakra: document.getElementById("b-chakra"),
  autoAtk: document.getElementById("b-autoatk"),
  kunai: document.getElementById("b-kunai"),
  shuriken: document.getElementById("b-shuriken"),
  senbon: document.getElementById("b-senbon"),
  ring1: document.getElementById("b-ring1"),
  ring2: document.getElementById("b-ring2"),
  jutsuTabs: document.getElementById("b-jutsu-tabs"),
  jutsuGrid: document.getElementById("b-jutsu-grid"),
  save: document.getElementById("b-save"),
  share: document.getElementById("b-share"),
  shareBox: document.getElementById("b-share-box"),
  shareLink: document.getElementById("b-share-link"),
  savedList: document.getElementById("b-saved-list"),
  sLevel: document.getElementById("s-level"),
  sVillage: document.getElementById("s-village"),
  sCorp: document.getElementById("s-corp"),
  sMasteries: document.getElementById("s-masteries"),
  sStats: document.getElementById("s-stats"),
  sWeapon: document.getElementById("s-weapon"),
  sRing1: document.getElementById("s-ring1"),
  sRing2: document.getElementById("s-ring2"),
};

const VILLAGE_LABELS = { folha: "Folha", areia: "Areia", neblina: "Névoa" };

// ---------------------------------------------------------------
// Render: formulário de personalização
// ---------------------------------------------------------------

function renderMasterySelects() {
  const options = [`<option value="">${t("builds_mastery_unassigned")}</option>`]
    .concat(masteries.map((m) => `<option value="${m.id}">${m.name}</option>`))
    .join("");
  el.mastery1.innerHTML = options;
  el.mastery2.innerHTML = options;
  el.mastery1.value = state.masteryId1;
  el.mastery2.value = state.masteryId2;
}

function renderWeaponModelOptions() {
  const filtered = state.weaponGroup ? weapons.filter((w) => w.weapon_group === state.weaponGroup) : [];
  el.weaponModel.innerHTML =
    `<option value="">${t("builds_weapon_model_none")}</option>` +
    filtered.map((w) => `<option value="${w.id}">${w.name}</option>`).join("");
  if (!filtered.some((w) => w.id === state.weaponId)) {
    state.weaponId = "";
  }
  el.weaponModel.value = state.weaponId;
}

function renderWeaponDetails() {
  const weapon = selectedWeapon();
  if (!weapon) {
    el.weaponDetails.innerHTML = "";
    return;
  }
  const reqs = Object.entries(weapon.weapon_requirements || {})
    .map(([k, v]) => `${k} ${v}`)
    .join(" · ");
  const buffs = Object.entries(weapon.weapon_buffs || {})
    .map(([k, v]) => `${k}: ${v}`)
    .join(" · ");
  const total = totalStats();
  const unmet = weaponUnmetRequirements(weapon, total);
  el.weaponDetails.innerHTML = `
    <p class="help-text" style="margin-top: 4px;">${weapon.description || ""}</p>
    <div class="build-summary__row"><dt>${t("builds_weapon_requirements")}</dt><dd>${reqs || "—"}</dd></div>
    ${buffs ? `<div class="build-summary__row"><dt>${t("builds_weapon_buffs")}</dt><dd>${buffs}</dd></div>` : ""}
    <div class="build-summary__row"><dt>${t("builds_weapon_rarity")}</dt><dd>${weapon.weapon_rarity || "—"}</dd></div>
    ${unmet.length ? `<p class="build-jutsu-card__lock">${t("builds_locked_reqs")}: ${unmet.join(", ")}</p>` : ""}
  `;
}

function renderStats() {
  const pool = pointPool(state.level);
  const allocated = STAT_KEYS.reduce((sum, k) => sum + (state.baseStats[k] - BASE_STAT), 0);
  const left = pool - allocated;
  el.pointsLeft.textContent = left;

  el.stats.innerHTML = STAT_KEYS.map((k) => {
    const value = state.baseStats[k];
    return `
      <div class="build-stat-row">
        <span class="build-stat-row__label">${STAT_FULL_LABELS[k]}</span>
        <button type="button" data-stat-dec="${k}" ${value <= BASE_STAT ? "disabled" : ""}>–</button>
        <span class="build-stat-row__value">${value}</span>
        <button type="button" data-stat-inc="${k}" ${left <= 0 ? "disabled" : ""}>+</button>
      </div>
    `;
  }).join("");

  el.stats.querySelectorAll("[data-stat-inc]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const k = btn.getAttribute("data-stat-inc");
      const poolNow = pointPool(state.level);
      const allocatedNow = STAT_KEYS.reduce((sum, kk) => sum + (state.baseStats[kk] - BASE_STAT), 0);
      if (poolNow - allocatedNow > 0) {
        state.baseStats[k] += 1;
        renderAll();
      }
    });
  });
  el.stats.querySelectorAll("[data-stat-dec]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const k = btn.getAttribute("data-stat-dec");
      if (state.baseStats[k] > BASE_STAT) {
        state.baseStats[k] -= 1;
        renderAll();
      }
    });
  });
}

function renderVitals() {
  const total = totalStats();
  const vitals = computeVitals(total);
  el.hp.textContent = vitals.hp;
  el.chakra.textContent = vitals.chakra;
  el.autoAtk.textContent = vitals.autoAtk;
  el.kunai.textContent = vitals.kunai;
  el.shuriken.textContent = vitals.shuriken;
  el.senbon.textContent = vitals.senbon;
}

function renderRing(container, ringSlots) {
  container.innerHTML = ringSlots
    .map(
      (slot, idx) => `
      <div class="build-ring-slot">
        <select data-ring-idx="${idx}" class="select">
          <option value="">${t("builds_ring_none")}</option>
          <option value="str" ${slot.stat === "str" ? "selected" : ""}>STR</option>
          <option value="for" ${slot.stat === "for" ? "selected" : ""}>FORT</option>
          <option value="int" ${slot.stat === "int" ? "selected" : ""}>INT</option>
          <option value="agi" ${slot.stat === "agi" ? "selected" : ""}>AGI</option>
          <option value="cha" ${slot.stat === "cha" ? "selected" : ""}>CHK</option>
        </select>
        <input type="number" data-ring-value-idx="${idx}" value="${slot.value || 0}" placeholder="0" />
      </div>
    `
    )
    .join("");
}

function bindRingEvents(container, ringSlots) {
  container.querySelectorAll("[data-ring-idx]").forEach((sel) => {
    sel.addEventListener("change", () => {
      const idx = Number(sel.getAttribute("data-ring-idx"));
      ringSlots[idx].stat = sel.value;
      renderAll();
    });
  });
  container.querySelectorAll("[data-ring-value-idx]").forEach((input) => {
    input.addEventListener("input", () => {
      const idx = Number(input.getAttribute("data-ring-value-idx"));
      ringSlots[idx].value = Number(input.value) || 0;
      renderVitals();
      renderSummary();
    });
  });
}

function renderRings() {
  renderRing(el.ring1, state.ring1);
  renderRing(el.ring2, state.ring2);
  bindRingEvents(el.ring1, state.ring1);
  bindRingEvents(el.ring2, state.ring2);
}

function renderJutsuTabs() {
  const tabMasteries = [state.masteryId1, state.masteryId2]
    .filter(Boolean)
    .map((id) => masteries.find((m) => m.id === id))
    .filter(Boolean);

  if (tabMasteries.length === 0) {
    el.jutsuTabs.innerHTML = "";
    el.jutsuGrid.innerHTML = `<p class="status-message">${t("builds_jutsus_pick_mastery")}</p>`;
    return;
  }

  if (!tabMasteries.some((m) => m.id === activeJutsuMasteryId)) {
    activeJutsuMasteryId = tabMasteries[0].id;
  }

  el.jutsuTabs.innerHTML = tabMasteries
    .map(
      (m) =>
        `<button type="button" class="build-jutsu-tab ${m.id === activeJutsuMasteryId ? "build-jutsu-tab--active" : ""}" data-mastery-tab="${m.id}">${m.name}</button>`
    )
    .join("");

  el.jutsuTabs.querySelectorAll("[data-mastery-tab]").forEach((btn) => {
    btn.addEventListener("click", () => {
      activeJutsuMasteryId = btn.getAttribute("data-mastery-tab");
      renderJutsuGrid();
    });
  });

  renderJutsuGrid();
}

function renderJutsuGrid() {
  const total = totalStats();
  const list = jutsusByMasteryId[activeJutsuMasteryId] || [];
  if (list.length === 0) {
    el.jutsuGrid.innerHTML = `<p class="status-message">${t("jutsus_none")}</p>`;
    return;
  }
  el.jutsuGrid.innerHTML = list
    .map((j) => {
      const locked = jutsuLocked(j, total);
      const dmg = jutsuDamage(j, total);
      return `
        <div class="build-jutsu-card ${locked ? "build-jutsu-card--locked" : ""}">
          <div class="build-jutsu-card__name">${j.name}</div>
          <div class="build-jutsu-card__meta">
            <span>${t("builds_level")} ${j.level_required}</span>
            <span>${j.stat_req_value} ${STAT_LABELS[j.stat_req_stat] || ""}</span>
          </div>
          <div class="build-jutsu-card__meta">
            <span>${t("builds_jutsu_dmg")}</span>
            <span class="build-jutsu-card__dmg">${dmg}</span>
          </div>
          ${locked ? `<div class="build-jutsu-card__lock">${t("builds_jutsu_locked")}</div>` : ""}
        </div>
      `;
    })
    .join("");
}

function renderSummary() {
  const total = totalStats();
  el.sLevel.textContent = state.level;
  el.sVillage.textContent = state.village ? VILLAGE_LABELS[state.village] || state.village : t("builds_village_none");
  el.sCorp.textContent = state.corp || t("builds_corporation_freelance");

  const m1 = masteries.find((m) => m.id === state.masteryId1);
  const m2 = masteries.find((m) => m.id === state.masteryId2);
  const path = [m1, m2].filter(Boolean).map((m) => m.name);
  el.sMasteries.textContent = path.length ? path.join(" / ") : t("builds_mastery_unassigned");

  el.sStats.innerHTML = STAT_KEYS.map(
    (k) => `
      <div class="build-summary__row">
        <dt>${STAT_FULL_LABELS[k]}</dt>
        <dd>${total[k]}</dd>
      </div>
    `
  ).join("");

  const weapon = selectedWeapon();
  el.sWeapon.textContent = weapon ? weapon.name : t("builds_weapon_none");

  const ring1Filled = state.ring1.filter((s) => s.stat);
  const ring2Filled = state.ring2.filter((s) => s.stat);
  el.sRing1.textContent = ring1Filled.length
    ? ring1Filled.map((s) => `${STAT_LABELS[s.stat]} +${s.value}`).join(", ")
    : t("builds_ring_none");
  el.sRing2.textContent = ring2Filled.length
    ? ring2Filled.map((s) => `${STAT_LABELS[s.stat]} +${s.value}`).join(", ")
    : t("builds_ring_none");
}

function renderSavedBuilds() {
  const list = loadSavedBuilds();
  if (list.length === 0) {
    el.savedList.innerHTML = `<p class="status-message">${t("builds_no_saved")}</p>`;
    return;
  }
  el.savedList.innerHTML = list
    .map(
      (b) => `
      <div class="build-saved-card">
        <span>${b.name} — ${t("builds_level")} ${b.level}</span>
        <span>
          <button type="button" class="btn btn-small" data-load-build="${b.id}">${t("builds_load")}</button>
          <button type="button" class="btn btn-small btn-danger" data-delete-build="${b.id}">${t("builds_delete")}</button>
        </span>
      </div>
    `
    )
    .join("");

  el.savedList.querySelectorAll("[data-load-build]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = Number(btn.getAttribute("data-load-build"));
      const found = loadSavedBuilds().find((b) => b.id === id);
      if (found) {
        state = { ...defaultState(), ...found.state };
        activeJutsuMasteryId = "";
        renderAll();
      }
    });
  });
  el.savedList.querySelectorAll("[data-delete-build]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const id = Number(btn.getAttribute("data-delete-build"));
      saveSavedBuilds(loadSavedBuilds().filter((b) => b.id !== id));
      renderSavedBuilds();
    });
  });
}

function syncFormFromState() {
  el.name.value = state.name;
  el.level.value = state.level;
  el.village.value = state.village;
  el.corp.value = state.corp;
  el.guildBuff.value = state.guildBuff;
  el.guildBuffValue.textContent = state.guildBuff;
  el.weaponGroup.value = state.weaponGroup;
}

function renderAll() {
  syncFormFromState();
  renderMasterySelects();
  renderWeaponModelOptions();
  renderWeaponDetails();
  renderStats();
  renderVitals();
  renderRings();
  renderJutsuTabs();
  renderSummary();
}

// ---------------------------------------------------------------
// Eventos de formulário
// ---------------------------------------------------------------

function bindFormEvents() {
  el.name.addEventListener("input", () => {
    state.name = el.name.value;
    renderSummary();
  });
  el.level.addEventListener("input", () => {
    let lvl = parseInt(el.level.value, 10);
    if (isNaN(lvl)) lvl = 1;
    lvl = Math.max(1, Math.min(70, lvl));
    state.level = lvl;
    renderAll();
  });
  el.village.addEventListener("change", () => {
    state.village = el.village.value;
    renderSummary();
  });
  el.mastery1.addEventListener("change", () => {
    state.masteryId1 = el.mastery1.value;
    activeJutsuMasteryId = "";
    renderJutsuTabs();
    renderSummary();
  });
  el.mastery2.addEventListener("change", () => {
    state.masteryId2 = el.mastery2.value;
    activeJutsuMasteryId = "";
    renderJutsuTabs();
    renderSummary();
  });
  el.corp.addEventListener("change", () => {
    state.corp = el.corp.value;
    renderSummary();
  });
  el.guildBuff.addEventListener("input", () => {
    state.guildBuff = Number(el.guildBuff.value);
    el.guildBuffValue.textContent = state.guildBuff;
    renderStats();
    renderVitals();
    renderWeaponDetails();
    renderJutsuGrid();
    renderSummary();
  });
  el.reset.addEventListener("click", () => {
    const name = state.name;
    state = defaultState();
    state.name = name;
    activeJutsuMasteryId = "";
    renderAll();
  });
  el.weaponGroup.addEventListener("change", () => {
    state.weaponGroup = el.weaponGroup.value;
    state.weaponId = "";
    renderWeaponModelOptions();
    renderWeaponDetails();
    renderVitals();
    renderSummary();
  });
  el.weaponModel.addEventListener("change", () => {
    state.weaponId = el.weaponModel.value;
    renderWeaponDetails();
    renderVitals();
    renderSummary();
  });
  el.save.addEventListener("click", () => {
    const list = loadSavedBuilds();
    list.unshift({ id: Date.now(), name: state.name, level: state.level, state: JSON.parse(JSON.stringify(state)) });
    saveSavedBuilds(list);
    renderSavedBuilds();
  });
  el.share.addEventListener("click", async () => {
    const encoded = encodeStateForShare();
    if (!encoded) return;
    const url = `${window.location.origin}${window.location.pathname}?b=${encoded}`;
    el.shareBox.style.display = "flex";
    el.shareLink.value = url;
    try {
      await navigator.clipboard.writeText(url);
      const original = el.share.textContent;
      el.share.textContent = t("builds_share_copied");
      setTimeout(() => {
        el.share.textContent = original;
      }, 1500);
    } catch {
      el.shareLink.select();
    }
  });
}

// ---------------------------------------------------------------
// Init
// ---------------------------------------------------------------

async function init() {
  mountGlobalControls();
  applyStaticTranslations();

  const loaded = await loadData();
  if (!loaded) return;

  loadStateFromUrl();
  bindFormEvents();
  renderAll();
  renderSavedBuilds();

  window.addEventListener("ninmap:langchange", () => {
    applyStaticTranslations();
    renderAll();
    renderSavedBuilds();
  });
}

init();

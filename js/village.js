/**
 * Vila selecionada pelo jogador (Névoa, Folha, Areia ou Renegados).
 *
 * A escolha é feita na tela inicial (index.html) e persiste no
 * navegador + na URL (?vila=neblina), pra ser reaproveitada em outras
 * páginas do site (ex: missions.html já abre filtrando pela vila
 * escolhida). No futuro, os pins do mapa também vão poder ser
 * filtrados por essa mesma escolha.
 */

import { VILLAGES } from "./config.js";

const STORAGE_KEY = "ninmap:vila";

export function getVillageById(id) {
  return VILLAGES.find((v) => v.id === id) || null;
}

export function getVillageFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("vila");
  return id && VILLAGES.some((v) => v.id === id) ? id : null;
}

export function getStoredVillage() {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch (e) {
    return null;
  }
}

export function storeVillage(id) {
  try {
    if (id) {
      localStorage.setItem(STORAGE_KEY, id);
    } else {
      localStorage.removeItem(STORAGE_KEY);
    }
  } catch (e) {
    /* ambiente sem localStorage disponível — ignora */
  }
}

/** Vila atual: prioriza a URL, depois a última escolhida no navegador. */
export function getCurrentVillage() {
  return getVillageFromUrl() || getStoredVillage() || null;
}

export function updateVillageInUrl(id) {
  const params = new URLSearchParams(window.location.search);
  if (id) {
    params.set("vila", id);
  } else {
    params.delete("vila");
  }
  const query = params.toString();
  const newUrl = `${window.location.pathname}${query ? `?${query}` : ""}`;
  window.history.replaceState({}, "", newUrl);
}

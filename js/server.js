/**
 * Servidor/comunidade escolhido (Toad = NA, Hawk = BR).
 *
 * Escolher o servidor já define o idioma padrão da interface (Toad →
 * inglês, Hawk → português) — quem cuida disso é js/chrome.js, que
 * também deixa trocar o idioma manualmente depois, independente do
 * servidor escolhido.
 */

export const SERVERS = [
  { id: "toad", label: "Toad Server (NA)", lang: "en" },
  { id: "hawk", label: "Hawk Server (BR)", lang: "pt" },
];

const STORAGE_KEY = "ninmap:server";

export function getServerById(id) {
  return SERVERS.find((s) => s.id === id) || null;
}

export function getServerFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const id = params.get("server");
  return id && SERVERS.some((s) => s.id === id) ? id : null;
}

export function getStoredServer() {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch (e) {
    return null;
  }
}

export function storeServer(id) {
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

export function getCurrentServer() {
  return getServerFromUrl() || getStoredServer() || null;
}

export function updateServerInUrl(id) {
  const params = new URLSearchParams(window.location.search);
  if (id) {
    params.set("server", id);
  } else {
    params.delete("server");
  }
  const query = params.toString();
  const newUrl = `${window.location.pathname}${query ? `?${query}` : ""}`;
  window.history.replaceState({}, "", newUrl);
}

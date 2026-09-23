/**
 * Helpers compartilhados pra upload/remoção de ícone no Supabase
 * Storage — usado em todos os cadastros que têm imagem (itens,
 * maestrias, jutsus). Todos usam o mesmo bucket público "item-icons"
 * (é só um bucket genérico de imagens, não precisa de um por tabela).
 */

import { supabase } from "./supabaseClient.js";

const BUCKET = "item-icons";

/** Extrai o "path" dentro do bucket a partir de uma public URL do storage. */
export function storagePathFromUrl(url) {
  if (!url) return null;
  const marker = `/object/public/${BUCKET}/`;
  const idx = url.indexOf(marker);
  if (idx === -1) return null;
  return url.slice(idx + marker.length);
}

export async function deleteImageFromStorage(url) {
  const path = storagePathFromUrl(url);
  if (!path) return;
  const { error } = await supabase.storage.from(BUCKET).remove([path]);
  if (error) console.error("Erro ao remover imagem antiga do storage:", error.message);
}

export async function uploadImage(file) {
  const ext = (file.name.split(".").pop() || "png").toLowerCase();
  const path = `${crypto.randomUUID()}.${ext}`;
  const { error } = await supabase.storage.from(BUCKET).upload(path, file, {
    cacheControl: "3600",
    upsert: false,
  });
  if (error) throw new Error(`Erro ao enviar imagem: ${error.message}`);
  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path);
  return data.publicUrl;
}

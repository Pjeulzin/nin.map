/**
 * Cliente Supabase compartilhado (módulo ES).
 * Importa o supabase-js via CDN — não precisa de build/npm.
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";
import { SUPABASE_URL, SUPABASE_ANON_KEY } from "./supabase-config.js";

export const isSupabaseConfigured =
  !SUPABASE_URL.includes("SEU-PROJETO") && !SUPABASE_ANON_KEY.includes("SUA-ANON-KEY");

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

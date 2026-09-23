import { supabase, isSupabaseConfigured } from "../../js/supabaseClient.js";

function showConfigError() {
  document.body.innerHTML = `
    <div class="auth-wrap">
      <div class="auth-card">
        <h1>Supabase não configurado</h1>
        <p class="help-text">
          Edite <code>js/supabase-config.js</code> com a URL e a anon key
          do seu projeto Supabase antes de usar a área de admin.
        </p>
      </div>
    </div>`;
}

/**
 * Garante que existe uma sessão ativa. Se não houver, redireciona pro
 * login. Use no topo de toda página do admin (menos a de login).
 */
export async function requireAuth() {
  if (!isSupabaseConfigured) {
    showConfigError();
    throw new Error("supabase not configured");
  }

  const {
    data: { session },
  } = await supabase.auth.getSession();

  if (!session) {
    window.location.href = "index.html";
    throw new Error("not authenticated");
  }

  return session;
}

export async function signOut() {
  await supabase.auth.signOut();
  window.location.href = "index.html";
}

export function wireLogoutButton(buttonId = "btn-logout") {
  const btn = document.getElementById(buttonId);
  if (btn) btn.addEventListener("click", signOut);
}

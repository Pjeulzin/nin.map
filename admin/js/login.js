import { supabase, isSupabaseConfigured } from "../../js/supabaseClient.js";

const form = document.getElementById("login-form");
const errorEl = document.getElementById("login-error");

if (!isSupabaseConfigured) {
  errorEl.textContent = "Supabase não configurado — edite js/supabase-config.js.";
} else {
  supabase.auth.getSession().then(({ data: { session } }) => {
    if (session) window.location.href = "pins.html";
  });
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  errorEl.textContent = "";

  const email = document.getElementById("email").value.trim();
  const password = document.getElementById("password").value;

  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    errorEl.textContent = `Login inválido: ${error.message}`;
    return;
  }

  window.location.href = "pins.html";
});

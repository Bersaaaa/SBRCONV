// ============================================================
// À compléter avec les identifiants de TON nouveau projet Supabase
// (Dashboard Supabase > Project Settings > API)
// ============================================================
const SUPABASE_URL = "https://mqqcysuvxuagfxpbbthb.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xcWN5c3V2eHVhZ2Z4cGJidGhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzMDYyMjYsImV4cCI6MjEwNDg4MjIyNn0.7oPjXvk-8ibcUUTfseAeYs25EFhOWpPx-ula_1a4mhU";

const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============================================================
// Notifications push (optionnel) — clé publique VAPID.
// Génère une paire de clés avec : npx web-push generate-vapid-keys
// Colle la clé PUBLIQUE ici, et la clé PRIVÉE comme secret de la
// fonction Edge "notify-mission" (VAPID_PRIVATE_KEY) — voir README.
// Laisse tel quel si tu n'actives pas les notifications push : le
// bouton "Activer les notifications" restera simplement inactif.
// ============================================================
const VAPID_PUBLIC_KEY = "";

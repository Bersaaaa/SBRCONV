// SBR AUTO — Fonction Edge "notify-mission"
//
// Déclenchée par un Database Webhook Supabase sur la table "missions" :
//  - INSERT (nouvelle mission "disponible") -> email aux prestataires
//    actifs dont la spécialité correspond au type de mission
//  - UPDATE (statut passe de "disponible" à "acceptee") -> email aux
//    admins pour les prévenir qu'une mission a été prise
//
// Envoi des emails via Resend (https://resend.com — gratuit jusqu'à
// 3000 emails/mois, aucune carte bancaire requise pour démarrer).
//
// Variables d'environnement à configurer (voir README) :
//   RESEND_API_KEY   - ta clé API Resend
//   RESEND_FROM      - adresse expéditrice, ex: "SBR AUTO <notifs@tondomaine.fr>"
//                       (ou "SBR AUTO <onboarding@resend.dev>" en test)
// SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont fournies automatiquement
// par Supabase à toutes les fonctions Edge, pas besoin de les définir.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const RESEND_FROM = Deno.env.get("RESEND_FROM") || "SBR AUTO <onboarding@resend.dev>";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const TYPE_LABEL: Record<string, string> = {
  convoyage: "Convoyage",
  nettoyage: "Nettoyage",
  inspection: "Inspection",
  autre: "Autre",
};

async function sendEmail(to: string, subject: string, html: string) {
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from: RESEND_FROM, to, subject, html }),
    });
    if (!res.ok) console.error("Resend error", await res.text());
  } catch (e) {
    console.error("Erreur envoi email", e);
  }
}

async function emailFor(userId: string): Promise<string | null> {
  const { data, error } = await supabase.auth.admin.getUserById(userId);
  if (error || !data?.user?.email) return null;
  return data.user.email;
}

Deno.serve(async (req) => {
  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return new Response("bad payload", { status: 400 });
  }

  const { type, table, record, old_record } = payload;
  if (table !== "missions") return new Response("ignored", { status: 200 });

  // --- Nouvelle mission publiée -> notifier les prestataires concernés ---
  if (type === "INSERT" && record.statut === "disponible") {
    const { data: prestataires, error } = await supabase
      .from("profiles")
      .select("id, nom")
      .eq("role", "prestataire")
      .eq("actif", true)
      .contains("specialites", [record.type]);

    if (!error) {
      for (const p of prestataires || []) {
        const email = await emailFor(p.id);
        if (!email) continue;
        await sendEmail(
          email,
          `Nouvelle mission ${TYPE_LABEL[record.type] || record.type} — ${record.titre}`,
          `<p>Bonjour ${p.nom},</p>
           <p>Une nouvelle mission vient d'être publiée sur SBR AUTO :</p>
           <p><strong>${record.titre}</strong> (${TYPE_LABEL[record.type] || record.type})<br>
           ${record.vehicule ? `Véhicule : ${record.vehicule}<br>` : ""}
           ${record.lieu_depart ? `Départ : ${record.lieu_depart}<br>` : ""}
           ${record.lieu_arrivee ? `Arrivée : ${record.lieu_arrivee}<br>` : ""}
           Prix : ${record.prix_ht} € HT</p>
           <p>Connecte-toi sur SBR AUTO pour l'accepter si tu es disponible.</p>`
        );
      }
    }
  }

  // --- Mission acceptée -> notifier les admins ---
  if (
    type === "UPDATE" &&
    old_record?.statut === "disponible" &&
    record.statut === "acceptee"
  ) {
    const { data: admins } = await supabase
      .from("profiles")
      .select("id")
      .eq("role", "admin");

    let prestataireNom = "Un prestataire";
    if (record.prestataire_id) {
      const { data: p } = await supabase
        .from("profiles")
        .select("nom")
        .eq("id", record.prestataire_id)
        .single();
      if (p) prestataireNom = p.nom;
    }

    for (const a of admins || []) {
      const email = await emailFor(a.id);
      if (!email) continue;
      await sendEmail(
        email,
        `Mission acceptée — ${record.titre}`,
        `<p>${prestataireNom} vient d'accepter la mission <strong>${record.titre}</strong>
         (${TYPE_LABEL[record.type] || record.type}).</p>`
      );
    }
  }

  return new Response("ok", { status: 200 });
});

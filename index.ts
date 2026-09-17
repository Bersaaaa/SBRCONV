// SBR CONVOYAGE — Fonction Edge "verify-document"
//
// Analyse un document déposé par un prestataire (Kbis, assurance pro, CNI,
// permis) via l'API Claude (Anthropic), pour un premier contrôle
// automatique en complément — jamais en remplacement — d'une vérification
// humaine. Le résultat est stocké dans la table "document_verifications",
// visible côté admin.
//
// Appelée directement par le client (inscription.html, prestataire.html)
// via supabaseClient.functions.invoke('verify-document', { body: {...} }),
// juste après l'upload d'un document.
//
// ⚠️ IMPORTANT — vie privée : la CNI et le permis de conduire contiennent
// des données personnelles. Ce fichier est envoyé à l'API Claude
// (Anthropic, société tierce) pour analyse. Les prompts ci-dessous
// demandent explicitement à l'IA de ne jamais recopier ces données dans
// son verdict (juste dire si le document est lisible et correspond au
// type attendu), mais le fichier lui-même transite par ce tiers. Mentionne
// ce traitement dans tes mentions légales / politique de confidentialité
// si tu actives cette fonction (voir mentions-legales.html).
//
// Variables d'environnement à configurer :
//   ANTHROPIC_API_KEY — ta clé API Anthropic (console.anthropic.com)
// SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont fournies automatiquement.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const DOC_PROMPTS: Record<string, string> = {
  kbis:
    "Ceci est un document fourni par un prestataire, censé être un extrait " +
    "Kbis (ou justificatif d'immatriculation d'entreprise français " +
    "équivalent). Vérifie s'il s'agit bien de ce type de document, s'il " +
    "est lisible, et si un nom d'entreprise et un numéro SIREN/SIRET sont " +
    "visibles. Réponds UNIQUEMENT en JSON strict, sans texte autour : " +
    '{"verdict":"conforme"|"a_verifier"|"suspect","commentaire":"<2 phrases max, en français>"}.',
  assurance:
    "Ceci est un document fourni par un prestataire, censé être une " +
    "attestation d'assurance responsabilité civile professionnelle. " +
    "Vérifie s'il s'agit bien de ce type de document, s'il est lisible, " +
    "et si une période de validité est visible. Réponds UNIQUEMENT en " +
    'JSON strict : {"verdict":"conforme"|"a_verifier"|"suspect","commentaire":"<2 phrases max, en français>"}.',
  cni:
    "Ceci est un document fourni par un prestataire, censé être une pièce " +
    "d'identité (CNI, passeport ou titre de séjour). Indique SEULEMENT " +
    "s'il s'agit bien d'un document d'identité officiel, lisible et non " +
    "manifestement trafiqué. Ne recopie JAMAIS le nom, la date de " +
    "naissance, l'adresse ou le numéro du document dans ta réponse. " +
    'Réponds UNIQUEMENT en JSON strict : {"verdict":"conforme"|"a_verifier"|"suspect","commentaire":"<2 phrases max, sans aucune donnée personnelle>"}.',
  permis:
    "Ceci est un document fourni par un prestataire, censé être un permis " +
    "de conduire. Indique SEULEMENT s'il s'agit bien d'un permis de " +
    "conduire officiel, lisible et non manifestement trafiqué. Ne " +
    "recopie JAMAIS le nom, la date de naissance ou le numéro du permis " +
    'dans ta réponse. Réponds UNIQUEMENT en JSON strict : {"verdict":"conforme"|"a_verifier"|"suspect","commentaire":"<2 phrases max, sans aucune donnée personnelle>"}.',
};

Deno.serve(async (req) => {
  try {
    const { prestataire_id, doc_type, path } = await req.json();
    if (!prestataire_id || !path || !DOC_PROMPTS[doc_type]) {
      return new Response(JSON.stringify({ error: "paramètres invalides" }), { status: 400 });
    }

    const { data: signedData, error: signErr } = await supabase
      .storage.from("documents").createSignedUrl(path, 300);
    if (signErr) throw signErr;

    const fileRes = await fetch(signedData.signedUrl);
    if (!fileRes.ok) throw new Error("Fichier introuvable");
    const contentType = fileRes.headers.get("content-type") || "application/octet-stream";
    const buf = new Uint8Array(await fileRes.arrayBuffer());

    // Taille de sécurité : on n'envoie pas des fichiers énormes à l'API
    if (buf.byteLength > 15 * 1024 * 1024) {
      throw new Error("Fichier trop volumineux pour la vérification automatique");
    }

    let binary = "";
    for (let i = 0; i < buf.length; i += 8192) {
      binary += String.fromCharCode(...buf.subarray(i, i + 8192));
    }
    const base64 = btoa(binary);

    const isPdf = contentType.includes("pdf");
    const mediaType = isPdf ? "application/pdf" : (contentType.includes("image") ? contentType : "image/jpeg");

    const aiRes = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: "claude-sonnet-5",
        max_tokens: 300,
        messages: [
          {
            role: "user",
            content: [
              {
                type: isPdf ? "document" : "image",
                source: { type: "base64", media_type: mediaType, data: base64 },
              },
              { type: "text", text: DOC_PROMPTS[doc_type] },
            ],
          },
        ],
      }),
    });

    if (!aiRes.ok) throw new Error("Erreur API Claude : " + (await aiRes.text()));
    const aiJson = await aiRes.json();
    const text = (aiJson.content || []).map((b: any) => b.text || "").join("");

    let parsed: { verdict?: string; commentaire?: string };
    try {
      parsed = JSON.parse(text.replace(/```json|```/g, "").trim());
    } catch {
      parsed = { verdict: "a_verifier", commentaire: "Analyse IA non exploitable — à vérifier manuellement." };
    }

    const verdict = ["conforme", "a_verifier", "suspect"].includes(parsed.verdict || "")
      ? parsed.verdict
      : "a_verifier";

    await supabase.from("document_verifications").upsert(
      {
        prestataire_id,
        doc_type,
        statut: verdict,
        commentaire: parsed.commentaire || null,
        verifie_le: new Date().toISOString(),
      },
      { onConflict: "prestataire_id,doc_type" }
    );

    return new Response(JSON.stringify({ ok: true, verdict }), { status: 200 });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

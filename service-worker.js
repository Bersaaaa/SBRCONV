// SBR CONVOYAGE — Service Worker
// Met en cache uniquement la coquille statique (HTML/CSS/icônes) pour un
// chargement instantané et l'installation en PWA. Les données (Supabase)
// ne sont JAMAIS mises en cache : toujours en direct depuis le réseau.

const CACHE_NAME = 'sbr-convoyage-v2';
const APP_SHELL = [
  './index.html',
  './connexion.html',
  './admin.html',
  './prestataire.html',
  './inscription.html',
  './mentions-legales.html',
  './cgv.html',
  './reinitialiser-mot-de-passe.html',
  './suivi.html',
  './style.css',
  './config.js',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Ne jamais mettre en cache les appels vers Supabase (données live)
  if (url.hostname.endsWith('supabase.co')) return;

  // Pour la coquille applicative : cache d'abord, réseau en secours
  if (event.request.method === 'GET' && url.origin === self.location.origin) {
    event.respondWith(
      caches.match(event.request).then((cached) => {
        return cached || fetch(event.request).then((res) => {
          const resClone = res.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, resClone));
          return res;
        }).catch(() => cached);
      })
    );
  }
});

self.addEventListener('push', (event) => {
  let payload = { title: 'SBR CONVOYAGE', body: 'Nouvelle notification', url: './' };
  try { payload = { ...payload, ...event.data.json() }; } catch (e) {}
  event.waitUntil(
    self.registration.showNotification(payload.title, {
      body: payload.body,
      icon: 'icons/icon-192.png',
      badge: 'icons/icon-192.png',
      data: { url: payload.url || './' }
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || './';
  event.waitUntil(clients.openWindow(url));
});

/* Service Worker SBR AUTO — cache la coquille de l'app pour un chargement
   instantané et un minimum de résilience hors-ligne. Les données (Supabase)
   passent toujours par le réseau : on ne cache jamais les appels API.

   Le numéro de version ci-dessous doit être incrémenté à chaque déploiement
   pour que les appareils détectent la mise à jour et proposent de recharger. */
const CACHE_NAME = 'sbrauto-shell-v3';
const SHELL_FILES = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png',
  '/icon-512-maskable.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(SHELL_FILES))
  );
  // Pas de skipWaiting() ici : le nouveau SW reste "en attente" tant que
  // l'utilisateur n'a pas confirmé le rechargement (voir bandeau dans l'app).
});

self.addEventListener('message', (event) => {
  if(event.data === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((names) =>
      Promise.all(names.filter((n) => n !== CACHE_NAME).map((n) => caches.delete(n)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const req = event.request;

  // On ne touche jamais aux écritures ni aux appels vers Supabase/API externes :
  // ils doivent toujours passer par le réseau, jamais par le cache.
  if (req.method !== 'GET' || !req.url.startsWith(self.location.origin)) return;

  // Navigation (chargement de la page) : réseau en priorité pour avoir la
  // dernière version, avec repli sur le cache si hors-ligne.
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put('/index.html', copy));
          return res;
        })
        .catch(() => caches.match('/index.html'))
    );
    return;
  }

  // Fichiers statiques de la coquille : cache en priorité, réseau en repli.
  event.respondWith(
    caches.match(req).then((cached) => cached || fetch(req))
  );
});

/* ---------------- notifications push (alertes temps réel) ---------------- */
self.addEventListener('push', (event) => {
  let data = { title: 'SBR AUTO', body: '', url: '/' };
  try { data = { ...data, ...event.data.json() }; } catch(e) {}
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/icon-192.png',
      badge: '/icon-192.png',
      data: { url: data.url || '/' },
      vibrate: [100, 50, 100],
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientsArr) => {
      for (const client of clientsArr) {
        if ('focus' in client) return client.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
    })
  );
});

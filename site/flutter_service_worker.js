// La web antigua (el juego en Flutter) dejaba instalado este service worker.
// Esta versión lo desinstala, borra su caché y recarga las pestañas abiertas con la web nueva.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const k of await caches.keys()) await caches.delete(k);
    await self.registration.unregister();
    for (const c of await self.clients.matchAll({ type: 'window' })) c.navigate(c.url);
  })());
});

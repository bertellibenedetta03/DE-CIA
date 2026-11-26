// DE CIA · Service worker dell'app Coincidenze
// Fa due cose: tiene l'app apribile anche con poca rete, e mostra le notifiche.
const CACHE = 'coincidenze-v2';
const FILE = ['/app/', '/app/app.css', '/app/app.js', '/app/dati.js', '/app/manifest.webmanifest', '/app/icone/icona.svg', '/app/icone/icona-192.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FILE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((chiavi) => Promise.all(chiavi.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Prima la rete (file sempre aggiornati). Se la rete manca, o non risponde entro
// 4 secondi (in treno capita spesso), si usa la copia salvata sul telefono.
self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== location.origin || !url.pathname.startsWith('/app/')) return;
  const copiaSalvata = () => caches.match(e.request, { ignoreSearch: true }).then((r) => r || caches.match('/app/'));
  const rete = fetch(e.request).then((r) => {
    if (r.ok) {
      const copia = r.clone();
      caches.open(CACHE).then((c) => c.put(e.request, copia));
    }
    return r;
  });
  const lenta = new Promise((ok) => setTimeout(ok, 4000)).then(copiaSalvata);
  e.respondWith(
    Promise.race([rete, lenta.then((r) => r || rete)])
      .then((r) => r || copiaSalvata())
      .catch(() => copiaSalvata())
  );
  e.waitUntil(rete.catch(() => {}));
});

self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (err) { d = { titolo: 'Coincidenze', testo: e.data ? e.data.text() : '' }; }
  e.waitUntil(
    self.registration.showNotification(d.titolo || 'Coincidenze', {
      body: d.testo || '',
      icon: '/app/icone/icona-192.png',
      badge: '/app/icone/icona-192.png',
      tag: 'coincidenze',
      renotify: true,
      data: { link: d.link || '/app/' },
    })
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const link = new URL((e.notification.data && e.notification.data.link) || '/app/', location.origin).href;
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((finestre) => {
      for (const f of finestre) {
        if (f.url.includes('/app/') && 'focus' in f) {
          return f.navigate(link).then((g) => (g || f).focus()).catch(() => f.focus());
        }
      }
      return self.clients.openWindow(link);
    })
  );
});

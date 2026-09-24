const CACHE_NAME = 'dallas-thc-v6';
const APP_SHELL = ['./manifest.json', './offline.html', './icons/club-icon.svg', './icons/icon-192.png', './icons/icon-512.png'];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('dallas-thc-') && key !== CACHE_NAME).map(key => caches.delete(key))))
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  const isHtmlPage = event.request.mode === 'navigate' || url.pathname.endsWith('.html') || url.pathname.endsWith('/Dallas-team-handball-club/');
  if (isHtmlPage) {
    event.respondWith(fetch(event.request, { cache: 'no-store' }).catch(() => caches.match('./offline.html')));
    return;
  }

  if (!/\.(?:js|css|png|svg|jpe?g|webp|ico|json)$/i.test(url.pathname)) return;
  event.respondWith(fetch(event.request).then(response => {
    if (response.ok) { const copy=response.clone();caches.open(CACHE_NAME).then(cache => cache.put(event.request, copy)); }
    return response;
  }).catch(() => caches.match(event.request)));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || './player-dashboard.html', self.registration.scope);
  if (target.origin !== self.location.origin || !target.href.startsWith(self.registration.scope)) return;
  event.waitUntil(clients.openWindow(target.href));
});

// Offline support. Game code and story: network first (so updates arrive), cache as offline fallback.
// Audio clips, icons, fonts: cache first (they never change once recorded).
const VERSION = 'tal-v5';
const SHELL = ['./', './index.html', './manifest.webmanifest', './audio/clips.js', './js/art.js', './js/icons.js', './js/people.js', './js/engine.js',
  './story/prologue.story', './icons/icon-192.png', './icons/icon-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

const put = (req, r) => { const copy = r.clone(); caches.open(VERSION).then(c => c.put(req, copy)); return r; };

self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  const fresh = url.origin === location.origin && (e.request.mode === 'navigate' || /\.(js|story|html|webmanifest)$/.test(url.pathname) || url.pathname.endsWith('/'));
  if (fresh) {
    e.respondWith(fetch(e.request).then(r => put(e.request, r)).catch(() => caches.match(e.request, { ignoreSearch: true })));
    return;
  }
  e.respondWith(caches.match(e.request).then(hit => hit || fetch(e.request).then(r => (r.ok || r.type === 'opaque') ? put(e.request, r) : r)));
});

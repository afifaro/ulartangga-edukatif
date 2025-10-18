// simple service worker for caching (optional)
const CACHE_NAME = 'ular-tangga-cache-v1';
const urlsToCache = [
  '/',
  '/index.html',
  '/style.css',
  '/script.js',
  '/manifest.json',
  '/assets/img/papan.png',
  '/assets/img/logo_kkg.jpg',
  '/assets/audio/musik_bawaan.wav'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(urlsToCache)));
});

self.addEventListener('fetch', e => {
  e.respondWith(caches.match(e.request).then(r => r || fetch(e.request)));
});

// Keeps the built assets in a cache of their own, and answers a navigation with
// an offline page when the network is gone.
//
// What it does NOT cache is every HTML page of the app. Those carry live
// readings, and a stale one is worse than no page at all: it would show power
// values from an hour ago as if they were current.
//
// A classic script, not a module: Safari only learned module workers in 16.4,
// and there is nothing here that needs the syntax.

// Bumped by hand when public/offline.html changes. A change to this file makes
// the browser reinstall the worker by itself, because it compares the bytes. A
// change to the offline page alone is invisible to it, and bumping this string
// is what makes it visible. The asset cache takes its name from the manifest,
// so a new build rotates it without help.
const VERSION = 'v1';

const OFFLINE_PAGE = '/offline.html';
const OFFLINE_CACHE = `offline-${VERSION}`;

// Where the built assets live. setupServiceWorker.ts passes it in, because the
// path differs between production (/vite/assets/) and test (/vite-test/assets/).
const ASSET_PREFIX =
  new URLSearchParams(self.location.search).get('assets') || '/vite/assets/';
const BASE = ASSET_PREFIX.replace(/assets\/$/, '');
const MANIFEST = `${BASE}manifest.json`;

// The manifest maps every entry to its built file, and names the CSS and the
// chunks each entry pulls in. Collecting all three covers what a cold page load
// asks for.
const assetPaths = (manifest) => {
  const paths = new Set();

  for (const entry of Object.values(manifest)) {
    if (typeof entry !== 'object' || entry === null) continue;

    if (typeof entry.file === 'string') paths.add(`${BASE}${entry.file}`);
    for (const path of [...(entry.css ?? []), ...(entry.assets ?? [])]) {
      paths.add(`${BASE}${path}`);
    }
  }

  return [...paths];
};

// The digest is not in the manifest itself, so derive one from its text. Two
// builds that produce the same files share a cache, and a changed build gets a
// fresh one. Eight bytes are far more than enough to tell two builds apart.
const digestOf = async (text) => {
  const bytes = new TextEncoder().encode(text);
  const hash = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(hash)]
    .slice(0, 8)
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
};

// Every asset under /vite/assets/ carries a content hash and is served
// immutable, so a cached one can never be stale: a change to the file changes
// its name. That makes the cache name the only thing tied to a build.
const readManifest = async () => {
  const response = await fetch(MANIFEST, { cache: 'no-cache' });
  if (!response.ok) throw new Error(`Cannot read ${MANIFEST}`);

  const text = await response.text();
  return {
    manifest: JSON.parse(text),
    cacheName: `assets-${await digestOf(text)}`,
  };
};

const precache = async () => {
  const { manifest, cacheName } = await readManifest();

  const cache = await caches.open(cacheName);
  // Individually, not addAll: one asset the build did not emit would otherwise
  // reject the whole install and leave the worker unable to take over.
  await Promise.allSettled(
    assetPaths(manifest).map((path) => cache.add(new Request(path))),
  );
};

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const offline = caches
        .open(OFFLINE_CACHE)
        .then((cache) =>
          cache.add(new Request(OFFLINE_PAGE, { cache: 'reload' })),
        );

      // A failed precache must not fail the install: the app works without it,
      // and the offline page is the part worth insisting on.
      await Promise.all([offline, precache().catch(() => {})]);

      await self.skipWaiting();
    })(),
  );
});

// Drop what an earlier build left behind. The names hold the digest and the
// version, so anything that is not the current pair is from a release before
// this one.
self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      // The name alone, not the assets: install has already filled that cache.
      const current = await readManifest()
        .then(({ cacheName }) => cacheName)
        .catch(() => null);
      const keep = [current, OFFLINE_CACHE].filter(Boolean);

      await Promise.all(
        (await caches.keys())
          .filter((name) => !keep.includes(name))
          .map((name) => caches.delete(name)),
      );

      await self.clients.claim();
    })(),
  );
});

// The offline page carries both languages, and the lang attribute decides which
// one it shows. Rails is not reachable at this point, so the language of the
// browser picks it. Not the `accept-language` header of the request: Chrome adds
// that below the service worker, so it is not here to read.
//
// A visitor who switched the language inside SOLECTRUS and away from the one the
// browser asks for sees the other language here. The app picks the language the
// same way on a first visit (see AutoLocale), so the two agree unless someone
// changed it by hand.
const offlinePage = async () => {
  const cached = await caches.match(OFFLINE_PAGE, {
    cacheName: OFFLINE_CACHE,
    ignoreSearch: true,
  });
  if (!cached) return Response.error();

  const german = /^de\b/i.test(self.navigator.language || '');
  const html = (await cached.text()).replace(
    '<html lang="de">',
    `<html lang="${german ? 'de' : 'en'}">`,
  );

  return new Response(html, {
    headers: { 'content-type': 'text/html; charset=utf-8' },
  });
};

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // A hashed asset is answered from the cache and never revalidated. It cannot
  // go stale, and this is the whole point of keeping it.
  if (url.pathname.startsWith(ASSET_PREFIX)) {
    event.respondWith(
      caches.match(request).then((hit) => hit || fetch(request)),
    );
    return;
  }

  // A page goes to the network every time, so the readings are the real ones.
  // Only a failed navigation falls back, and it falls back to a page that says
  // the app is offline rather than to a copy pretending to be current.
  if (request.mode === 'navigate') {
    event.respondWith(fetch(request).catch(offlinePage));
  }
});

import { metaContent } from '@/utils/metaContent';

// Registers public/service-worker.js, which keeps the built assets in a cache
// and answers a navigation with public/offline.html when the network is gone.
//
// Not in development: Vite serves unbundled modules from its own origin there,
// so there is nothing to precache, and a worker that outlives a restart of the
// dev server serves files that no longer exist.
export function setupServiceWorker() {
  if (!('serviceWorker' in navigator)) return;

  if (metaContent('env') === 'development') {
    // A worker registered by an earlier production visit to the same host
    // (solectrus.localhost) would keep control here. Clear it out.
    void navigator.serviceWorker
      .getRegistrations()
      .then((registrations) =>
        registrations.forEach((registration) => void registration.unregister()),
      );
    return;
  }

  // Where the built assets live: /vite/assets/ in production, /vite-test/assets/
  // under test. Taken from the URL of this very module, so the worker does not
  // need a second source of truth for it.
  const assets = new URL(/* @vite-ignore */ '.', import.meta.url).pathname;

  // The version in the URL makes every release install the worker anew. The
  // browser compares only the bytes of the script, and those stay the same
  // from one release to the next, so without it a new build would never be
  // precached and the cache of the old one would stay behind.
  const params = new URLSearchParams({
    assets,
    v: metaContent('version') ?? '',
  });

  // After load, so the registration never competes with the first paint for
  // bandwidth or main thread time.
  window.addEventListener('load', () => {
    // A browser refuses the worker without a trusted certificate, or in a
    // private window. The app works without it, so there is nothing to report.
    navigator.serviceWorker
      .register(`/service-worker.js?${params}`)
      .catch(() => {});
  });
}

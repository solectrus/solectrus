import Plausible from 'plausible-tracker';

document.addEventListener('turbo:load', () => {
  const plausibleUrl = document.querySelector(
    'meta[name="plausible-url"]',
  )?.content;
  if (plausibleUrl) {
    const plausible = Plausible({
      domain: document.querySelector('meta[name="app-host"]').content,
      apiHost: plausibleUrl,
    });

    plausible.trackPageview();
  }
});

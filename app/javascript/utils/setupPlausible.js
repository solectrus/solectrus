import Plausible from 'plausible-tracker';
import { metaContent } from './metaContent';

document.addEventListener('turbo:load', () => {
  const plausibleUrl = metaContent('plausible-url');
  if (plausibleUrl) {
    const plausible = Plausible({
      domain: metaContent('app-host') || window.location.host,
      apiHost: plausibleUrl,
    });

    plausible.trackPageview();
  }
});

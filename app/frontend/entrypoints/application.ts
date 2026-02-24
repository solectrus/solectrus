import '@hotwired/turbo-rails';
import.meta.glob('../channels/**/*_channel.{js,ts}', { eager: true });

import '@/utils/setupHoneyBadger';
import '@/utils/setupStimulus';
import { metaContent } from '@/utils/metaContent';

if (metaContent('env') != 'development') {
  // Prevent right-click on touch devices
  window.onload = () => {
    if ('ontouchstart' in window) {
      document.addEventListener('contextmenu', (e) => {
        e.preventDefault();
        return false;
      });
    }
  };
}

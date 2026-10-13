import '@hotwired/turbo-rails';
import.meta.glob('../images/**', { eager: true });

import '@/utils/setupHoneyBadger';
import '@/utils/setupStimulus';
import { setupHistoryTrail } from '@/utils/historyTrail';
import { metaContent } from '@/utils/metaContent';
import { setupSamePageVisits } from '@/utils/setupSamePageVisits';
import { setupServiceWorker } from '@/utils/setupServiceWorker';
import { setupTapFeedback } from '@/utils/setupTapFeedback';

setupServiceWorker();
setupHistoryTrail();
setupSamePageVisits();
setupTapFeedback();

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

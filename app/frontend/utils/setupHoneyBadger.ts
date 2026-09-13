import Honeybadger from '@honeybadger-io/js';
import { metaContent } from './metaContent';

// Messages browsers use when a fetch dies mid-flight: the user locked the
// phone, switched tabs or lost connectivity. They arrive without a stack
// trace and are not caused by a bug in the application.
const networkErrorMessages = [
  'Load failed', // Safari
  'Failed to fetch', // Chrome
  'NetworkError when attempting to fetch resource', // Firefox
];

// Benign browser noise: a ResizeObserver could not deliver all of its
// notifications within one animation frame, so the browser retries on the
// next one. Nothing is lost and no layout breaks, but Safari and Chrome
// report it through window.onerror. See w3c/csswg-drafts#5023.
const resizeObserverMessages = [
  'ResizeObserver loop completed with undelivered notifications',
  'ResizeObserver loop limit exceeded',
];

const ignoredMessages = [...networkErrorMessages, ...resizeObserverMessages];

const honeybadgerApiKey = metaContent('honeybadger-api-key');
if (honeybadgerApiKey) {
  const gitCommitVersion = metaContent('git-commit-version');

  Honeybadger.configure({
    apiKey: honeybadgerApiKey,
    environment: 'production',
    revision: gitCommitVersion,
  });

  Honeybadger.beforeNotify((notice) => {
    // Ignore AbortError - these occur when users navigate away before
    // a fetch request completes, which is normal browser behavior
    if (notice?.name === 'AbortError') return false;

    const message = notice?.message ?? '';
    if (ignoredMessages.some((needle) => message.includes(needle)))
      return false;
  });
}

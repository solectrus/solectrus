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
    if (networkErrorMessages.some((needle) => message.includes(needle)))
      return false;
  });
}

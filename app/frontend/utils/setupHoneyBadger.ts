import Honeybadger from '@honeybadger-io/js';
import { metaContent } from './metaContent';

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
  });
}

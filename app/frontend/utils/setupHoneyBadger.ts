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

// Safari hides the URL of scripts injected by browser extensions (password
// managers, content blockers) behind this placeholder. Errors carrying it come
// from such an extension, never from the application.
const extensionMessages = ['webkit-masked-url://'];

// The in-app browsers of Facebook and Instagram on iOS inject an autofill
// script into every page. It calls a callback their WebView does not always
// define, and the error is reported against the page itself.
const inAppBrowserMessages = ['_AutofillCallbackHandler'];

const ignoredMessages = [
  ...networkErrorMessages,
  ...resizeObserverMessages,
  ...extensionMessages,
  ...inAppBrowserMessages,
];

// Other browsers keep the real URL of an extension script. An error thrown in
// such a script (a crypto wallet that fails to connect, for example) is noise
// as well. Only the frame that threw counts: an extension that merely wraps a
// browser API must not hide the errors of the application passing through it.
const extensionUrlPrefixes = [
  'chrome-extension://',
  'moz-extension://',
  'safari-extension://',
  'safari-web-extension://',
];

const thrownByExtension = (file: string | undefined) =>
  !!file && extensionUrlPrefixes.some((prefix) => file.startsWith(prefix));

// Most installations have no API key, so the library loads only with one. The
// import does not wait: the app starts at once, and the errors of its first
// moments go unreported.
const honeybadgerApiKey = metaContent('honeybadger-api-key');
if (honeybadgerApiKey) {
  import('@honeybadger-io/js').then(({ default: Honeybadger }) => {
    Honeybadger.configure({
      apiKey: honeybadgerApiKey,
      environment: 'production',
      revision: metaContent('version'),
    });

    Honeybadger.beforeNotify((notice) => {
      // Ignore AbortError - these occur when users navigate away before
      // a fetch request completes, which is normal browser behavior
      if (notice?.name === 'AbortError') return false;

      const message = notice?.message ?? '';
      if (ignoredMessages.some((needle) => message.includes(needle)))
        return false;

      if (thrownByExtension(notice?.backtrace?.[0]?.file)) return false;
    });
  });
}

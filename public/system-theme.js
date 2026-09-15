// Applies the theme of the operating system, for a visitor who follows it.
// Only the browser knows that setting, so the server leaves the class off the
// html tag and this fills it in. See app/components/system_theme/component.rb.
//
// A file and not an inline script: `script-src 'self'` allows it as it is, with
// no nonce and no hash. It has to stay a classic script, because a module would
// be deferred and run after the first paint, which is the flash it prevents.
try {
  if (matchMedia('(prefers-color-scheme: dark)').matches)
    document.documentElement.classList.add('dark');
} catch (e) {}

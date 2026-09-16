// The locale for client-side formatting (dates, numbers, currencies).
//
// Rails renders the chosen UI language into <html lang="...">, so the DOM is
// the source of truth. The browser language is only a fallback: it is often
// different from the language the user picked in SOLECTRUS.
export function appLocale(): string {
  const documentLocale = sanitize(document.documentElement.lang);
  if (documentLocale) return documentLocale;

  return sanitize(navigator.language) || 'en';
}

// Remove invalid suffixes like @posix that some browsers return,
// e.g. "en-US@posix" -> "en-US"
function sanitize(locale: string | null | undefined): string {
  return locale?.split('@')[0].trim() ?? '';
}

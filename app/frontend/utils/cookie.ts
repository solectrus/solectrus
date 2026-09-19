// Preferences the server has to know before it renders: the theme and the
// color palette. A cookie and not localStorage, because the layout reads it and
// puts the right class on the html tag with the first byte. localStorage would
// only arrive once the browser runs our JavaScript, which is after the paint.

const ONE_YEAR = 60 * 60 * 24 * 365;

export function readCookie(name: string): string | null {
  const match = document.cookie.match(new RegExp(`(?:^|;\\s*)${name}=([^;]*)`));

  return match ? decodeURIComponent(match[1]) : null;
}

// A null value deletes the cookie, which is how a preference returns to its
// default: no cookie, and the server renders that default.
export function writeCookie(name: string, value: string | null) {
  const secure = location.protocol === 'https:' ? '; secure' : '';
  const age = value === null ? 0 : ONE_YEAR;

  document.cookie = `${name}=${value ?? ''}; path=/; max-age=${age}; samesite=lax${secure}`;
}

// Both preferences lived in localStorage before. Move a leftover value into the
// cookie once, so nobody has to pick their theme and palette again. The legacy
// key goes in any case: a later return to the default must not resurrect it.
export function migrateFromLocalStorage(name: string, legacyKey: string) {
  const legacy = localStorage.getItem(legacyKey);
  if (legacy === null) return;

  localStorage.removeItem(legacyKey);
  if (readCookie(name) === null) writeCookie(name, legacy);
}

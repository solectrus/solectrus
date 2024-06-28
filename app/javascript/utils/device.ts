export function isTouchEnabled(): boolean {
  return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
}

export function isReducedMotion(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

export function isIOS(): boolean {
  return /iPad|iPhone|iPod/.test(navigator.userAgent || '');
}

// Immediate press feedback for touch.
//
// iOS holds `:active` back for a moment after a finger lands: it waits to see
// whether the touch turns into a scroll. Tailwind's preflight also clears
// `-webkit-tap-highlight-color`, so the gray overlay iOS would draw by itself
// is gone as well. Together that leaves a tap on a link with no reaction at
// all until the next page renders - a quarter of a second at best, half a
// second over a real network.
//
// So set the state here. `pointerdown` fires as the finger lands, with no
// wait, and the class it sets drives the same `scale-95` that `:active` does
// (see `.click-animation` in application.css).
//
// Touch and pen only. A mouse gets `:active` without any delay, and the
// browser already handles it.
export function setupTapFeedback() {
  let pressed: Element | null = null;

  const release = () => {
    pressed?.classList.remove('is-pressed');
    pressed = null;
  };

  document.addEventListener(
    'pointerdown',
    (event) => {
      if (event.pointerType === 'mouse') return;

      const target = (event.target as Element | null)?.closest?.(
        'a[href], button',
      );
      if (!target) return;

      release();
      pressed = target;
      target.classList.add('is-pressed');
    },
    { capture: true, passive: true },
  );

  // `pointercancel` covers the tap that turns into a scroll, `turbo:load` the
  // element that survives a morph and would otherwise stay pressed.
  for (const event of [
    'pointerup',
    'pointercancel',
    'turbo:load',
    'turbo:render',
  ]) {
    document.addEventListener(event, release, { capture: true, passive: true });
  }
}

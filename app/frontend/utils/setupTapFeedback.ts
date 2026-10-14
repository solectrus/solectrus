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
//
// iOS fires `click` about 130ms after the finger lifts. A press that ends on
// `pointerup` would come back for that time, and only then would the tap
// take effect: the element flickers. So the press lasts until the `click`,
// or until RELEASE_DELAY when no click follows.
const RELEASE_DELAY = 400;

export function setupTapFeedback() {
  let pressed: Element | null = null;
  let timer: ReturnType<typeof setTimeout> | undefined;

  const release = () => {
    clearTimeout(timer);
    pressed?.classList.remove('is-pressed');
    pressed = null;
  };

  const releaseLater = () => {
    clearTimeout(timer);
    timer = setTimeout(release, RELEASE_DELAY);
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

  document.addEventListener('pointerup', releaseLater, {
    capture: true,
    passive: true,
  });

  // `click` ends the press in the same task as the action it starts.
  // `pointercancel` covers the tap that turns into a scroll, `turbo:load` the
  // element that survives a morph and would otherwise stay pressed.
  for (const event of [
    'click',
    'pointercancel',
    'turbo:load',
    'turbo:render',
  ]) {
    document.addEventListener(event, release, { capture: true, passive: true });
  }
}

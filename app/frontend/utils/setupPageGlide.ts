import { isReducedMotion } from '@/utils/device';
import { EASE_GLIDE } from '@/utils/motion';

const desktop = window.matchMedia('(min-width: 64rem)');

type RenderEvent = CustomEvent<{ render: (...args: unknown[]) => unknown }>;
type Box = NonNullable<ReturnType<typeof measure>>;
type Glide = { move?: Animation; size?: Animation; end: Box };

// On desktop, the card glides from the place and height of the old page or
// frame to the new one. A page without a sub navigation starts its card
// higher. The glide wraps the render of Turbo, so it starts before the
// browser paints the new content in its new place.
//
// A page that still loads a frame keeps at least the height of the old
// page, so the card does not shrink to the empty page first and grow again.
// While the card glides or waits, it follows each change of its content,
// from a frame or a stream, from where it is.
//
// The move and the height are two glides. A change that keeps the end of
// one lets that glide go on at its own pace: the frames of a page often
// change only the height, and the card must not stop and start its move
// again for that. Alone, the move can also run off the main thread, so a
// chart that draws does not stop it.
export function setupPageGlide() {
  let glide: Glide | undefined;
  const changes = new MutationObserver(() => follow());

  const drop = () => {
    glide?.move?.cancel();
    glide?.size?.cancel();
  };

  const stop = () => {
    drop();
    glide = undefined;
    changes.disconnect();
  };

  const follow = (from = measure()) => {
    const to = measureWithout(glide);
    if (!from || !to) return stop();

    const loading = to.card.querySelector('turbo-frame[busy]') !== null;
    if (loading) to.height = Math.max(to.height, from.height);
    const fill = loading ? 'forwards' : 'none';

    if (!loading && same(from, to)) return stop();

    // The glides of an old page leave with it
    const kept = glide?.end.card === to.card ? glide : undefined;
    if (!kept) drop();
    const timing = { duration: 350, easing: EASE_GLIDE };

    let { move, size } = kept ?? {};
    if (kept?.end.top !== to.top) {
      move?.cancel();
      move =
        from.top === to.top
          ? undefined
          : to.card.animate(
              { translate: [`0 ${from.top - to.top}px`, '0 0'] },
              timing,
            );
    }

    if (kept?.end.height === to.height) {
      size?.effect?.updateTiming({ fill });
    } else {
      size?.cancel();
      size =
        from.height === to.height && !loading
          ? undefined
          : to.card.animate(
              {
                height: [`${from.height}px`, `${to.height}px`],
                overflow: ['clip', 'clip'],
              },
              { ...timing, fill },
            );
    }

    glide = { move, size, end: to };

    changes.disconnect();
    changes.observe(to.card, {
      subtree: true,
      childList: true,
      attributeFilter: ['busy'],
    });

    // Lets go of the card, so an old page does not stay in memory
    const done = () => {
      if ([move, size].every((part) => part?.playState !== 'running')) stop();
    };
    if (move) move.onfinish = loading ? null : done;
    if (size) size.onfinish = loading ? null : done;
    if (!loading) done();
  };

  const wrap = (event: Event) => {
    if (!desktop.matches || isReducedMotion()) return;

    const { detail } = event as RenderEvent;
    const render = detail.render;
    detail.render = async (...args) => {
      const from = measure();
      await render(...args);
      follow(from);
    };
  };

  document.addEventListener('turbo:before-render', wrap);
  document.addEventListener('turbo:before-frame-render', wrap);
}

// The top in the document, so a scroll to the top of the new page does not
// count as a move
function measure() {
  const card = document.getElementById('inner');
  if (!card) return;

  const { top, height } = card.getBoundingClientRect();
  return { card, top: Math.round(top + scrollY), height: Math.round(height) };
}

// The card without its glides gives the end of its content. The glides leave
// the card only for the measure and keep their time, so they go on in the
// next frame without a pause.
function measureWithout(glide: Glide | undefined) {
  const effects = [glide?.move?.effect, glide?.size?.effect].filter(
    (effect) => effect instanceof KeyframeEffect,
  );
  const targets = effects.map((effect) => effect.target);
  effects.forEach((effect) => (effect.target = null));
  const box = measure();
  effects.forEach((effect, index) => (effect.target = targets[index]));
  return box;
}

function same(a: Box, b: Box) {
  return a.top === b.top && a.height === b.height;
}

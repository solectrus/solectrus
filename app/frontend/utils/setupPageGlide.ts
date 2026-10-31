import { isReducedMotion } from '@/utils/device';
import { EASE_GLIDE } from '@/utils/motion';

const desktop = window.matchMedia('(min-width: 64rem)');

type RenderEvent = CustomEvent<{ render: (...args: unknown[]) => unknown }>;
type Box = ReturnType<typeof measure>;

// On desktop, the card glides from the place and height of the old page or
// frame to the new one. A page without a sub navigation starts its card
// higher. The glide wraps the render of Turbo, so it starts before the
// browser paints the new content in its new place.
//
// A page that still loads a frame keeps at least the height of the old
// page, so the card does not shrink to the empty page first and grow again.
// While the card glides or waits, it follows each change of its content,
// from a frame or a stream, from where it is. A change that keeps its end
// lets the glide go on.
export function setupPageGlide() {
  let glide: Animation | undefined;
  let end: Box;
  const changes = new MutationObserver(() => follow());

  const stop = () => {
    glide = undefined;
    end = undefined;
    changes.disconnect();
  };

  const follow = (from = measure()) => {
    // The card without the glide gives the end of its content
    const time = glide?.currentTime;
    glide?.cancel();
    const to = measure();
    if (!from || !to) return stop();

    const loading = to.card.querySelector('turbo-frame[busy]') !== null;
    if (loading) to.height = Math.max(to.height, from.height);
    const fill = loading ? 'forwards' : 'none';

    if (glide && time != null && to.card === end?.card && same(to, end)) {
      glide.effect?.updateTiming({ fill });
      glide.currentTime = time;
      glide.play();
    } else {
      if (!loading && same(from, to)) return stop();

      end = to;
      glide = to.card.animate(
        {
          translate: [`0 ${from.top - to.top}px`, '0 0'],
          height: [`${from.height}px`, `${to.height}px`],
          overflow: ['clip', 'clip'],
        },
        { duration: 350, easing: EASE_GLIDE, fill },
      );
    }

    // Lets go of the card, so an old page does not stay in memory
    glide.onfinish = loading ? null : stop;
    changes.disconnect();
    changes.observe(to.card, {
      subtree: true,
      childList: true,
      attributeFilter: ['busy'],
    });
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

function same(a: Box, b: Box) {
  return a?.top === b?.top && a?.height === b?.height;
}

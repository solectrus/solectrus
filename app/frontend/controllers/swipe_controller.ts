import { Controller } from '@hotwired/stimulus';
import { isReducedMotion, isTouchEnabled } from '@/utils/device';

// Turns the page to the period before or after with a horizontal swipe, as a
// pager of a phone does: the content follows the finger, a committed swipe
// slides it out to the side, and the next page slides in from the other side.
//
// A swipe commits by its speed at the end (a flick) or by its distance. A
// flick back against the drag springs back, whatever the distance.
//
// The links of the timeframe (`data-nav`) give the pages, the first ones on
// the page. The live view has them only in the period of a phone, hidden,
// where they lead to yesterday and to the forecast (see
// Timeframe::Pager::Component).

// A flick commits above this speed, in px per ms, measured over the last
// moves of the finger
const FLICK_VELOCITY = 0.35;
const VELOCITY_WINDOW = 100;
// A slow drag commits beyond this fraction of the width
const COMMIT_DISTANCE_RATIO = 0.4;
// Strong dampening when there is no page in that direction (rubber-band)
const RUBBER_BAND_FACTOR = 0.15;
// Movement (px) required before the gesture locks to horizontal or vertical
const AXIS_LOCK_THRESHOLD = 10;
// Touches starting inside this margin from the viewport edge are left to the
// browser so iOS Safari / Android Chrome edge swipe-back still works
const EDGE_MARGIN = 20;
// The slide out keeps the speed of the finger within these bounds, the slide
// in eases like a sheet of iOS
const OUT_DURATION = { min: 120, max: 260 };
const IN_DURATION = 320;
const EASE_OUT = 'cubic-bezier(0.2, 0.8, 0.2, 1)';
const EASE_IN = 'cubic-bezier(0.32, 0.72, 0, 1)';
const SPRING_BACK = `transform 250ms ${EASE_IN}`;
const DRAG_TARGET = '#inner';

// A committed swipe while its page loads. Turbo replaces the body, and with
// it this controller, so the turn lives here. `direction` is the side the old
// content leaves to: -1 to the left for the next page, 1 to the right.
type Turn = { direction: 1 | -1; out: Promise<void> };
let turn: Turn | null = null;

type BeforeRenderDetail = {
  newBody: HTMLElement;
  resume: (value?: unknown) => void;
};

// The new page waits until the old content has left, and starts beside the
// screen, on the side the finger came from
document.addEventListener('turbo:before-render', async (event) => {
  if (!turn) return;

  const { direction, out } = turn;
  const { detail } = event as CustomEvent<BeforeRenderDetail>;
  event.preventDefault();
  await out;

  const inner = detail.newBody.querySelector<HTMLElement>(DRAG_TARGET);
  if (inner) {
    inner.style.transition = 'none';
    inner.style.transform = `translate3d(${-direction * 100}%, 0, 0)`;
  }
  detail.resume();
});

document.addEventListener('turbo:render', () => {
  if (!turn) return;

  turn = null;
  const inner = document.querySelector<HTMLElement>(DRAG_TARGET);
  if (!inner?.style.transform) return;

  // Two frames, so the browser paints the start beside the screen first
  requestAnimationFrame(() =>
    requestAnimationFrame(() => {
      inner.style.transition = `transform ${IN_DURATION}ms ${EASE_IN}`;
      inner.style.transform = '';
      inner.addEventListener(
        'transitionend',
        () => (inner.style.transition = ''),
        { once: true },
      );
    }),
  );
});

// The content stays visible while it slides out, instead of the blank page of
// a visit on a phone (see application.css)
document.addEventListener('turbo:load', () => {
  delete document.documentElement.dataset.navSliding;
});

document.addEventListener('turbo:fetch-request-error', () => {
  if (!turn) return;

  turn = null;
  delete document.documentElement.dataset.navSliding;
  const inner = document.querySelector<HTMLElement>(DRAG_TARGET);
  if (inner) {
    inner.style.transition = SPRING_BACK;
    inner.style.transform = '';
  }
});

export default class extends Controller<HTMLElement> {
  private touchStartX = 0;
  private touchStartY = 0;
  private rawDeltaX = 0;
  // The last positions of the finger, for its speed at the end
  private samples: { x: number; t: number }[] = [];
  private axis: 'horizontal' | 'vertical' | null = null;
  private dragTarget: HTMLElement | null = null;
  // Cached per gesture to keep the touchmove hot path free of DOM/media queries
  private prevLink: HTMLAnchorElement | null = null;
  private nextLink: HTMLAnchorElement | null = null;
  private pendingSpringBackCleanup: (() => void) | null = null;

  private boundHandleTouchStart?: (event: TouchEvent) => void;
  private boundHandleTouchMove?: (event: TouchEvent) => void;
  private boundHandleTouchEnd?: (event: TouchEvent) => void;

  connect() {
    if (!isTouchEnabled()) return;

    this.boundHandleTouchStart = this.handleTouchStart.bind(this);
    this.boundHandleTouchMove = this.handleTouchMove.bind(this);
    this.boundHandleTouchEnd = this.handleTouchEnd.bind(this);

    this.element.addEventListener('touchstart', this.boundHandleTouchStart, {
      passive: true,
    });
    // touchmove needs passive:false so we can preventDefault once the gesture
    // is locked horizontally — on <body> the default would otherwise be passive
    this.element.addEventListener('touchmove', this.boundHandleTouchMove, {
      passive: false,
    });
    this.element.addEventListener('touchend', this.boundHandleTouchEnd, {
      passive: true,
    });
    this.element.addEventListener('touchcancel', this.boundHandleTouchEnd, {
      passive: true,
    });
  }

  disconnect() {
    if (!isTouchEnabled()) return;

    // Fire any pending spring-back cleanup so its transitionend listener does
    // not outlive the controller on a morph-surviving #inner element
    this.pendingSpringBackCleanup?.();

    if (this.boundHandleTouchStart) {
      this.element.removeEventListener(
        'touchstart',
        this.boundHandleTouchStart,
      );
    }
    if (this.boundHandleTouchMove) {
      this.element.removeEventListener('touchmove', this.boundHandleTouchMove);
    }
    if (this.boundHandleTouchEnd) {
      this.element.removeEventListener('touchend', this.boundHandleTouchEnd);
      this.element.removeEventListener('touchcancel', this.boundHandleTouchEnd);
    }
  }

  private handleTouchStart(event: TouchEvent) {
    // A page that is turning takes no new swipe
    if (turn) {
      this.dragTarget = null;
      return;
    }

    // Abort any spring-back still in flight from a previous gesture so its
    // transitionend listener can't leak — the new touch interrupts the
    // transition, which would otherwise never fire
    this.pendingSpringBackCleanup?.();

    const touch = event.changedTouches[0];

    // Leave gestures starting near the viewport edge to the browser so native
    // swipe-back/forward (iOS Safari, Android Chrome) still works
    if (
      touch.clientX < EDGE_MARGIN ||
      touch.clientX > window.innerWidth - EDGE_MARGIN
    ) {
      this.dragTarget = null;
      return;
    }

    // Chart canvases handle their own horizontal touch gestures (tooltip
    // crosshair). Leave them alone so dragging the tooltip does not also
    // rubber-band the surrounding page. A sheet above the page (a dialog)
    // has its own gestures, and the page below must not turn over.
    if (
      event.target instanceof Element &&
      event.target.closest('canvas, dialog')
    ) {
      this.dragTarget = null;
      return;
    }

    this.touchStartX = touch.screenX;
    this.touchStartY = touch.screenY;
    this.rawDeltaX = 0;
    this.samples = [{ x: 0, t: event.timeStamp }];
    this.axis = null;
    this.dragTarget = document.querySelector<HTMLElement>(DRAG_TARGET);
    this.prevLink =
      document.querySelector<HTMLAnchorElement>('a[data-nav="prev"]');
    this.nextLink =
      document.querySelector<HTMLAnchorElement>('a[data-nav="next"]');

    if (this.dragTarget) {
      // Drop any leftover transition so the element follows the finger
      // without delay
      this.dragTarget.style.transition = 'none';
    }
  }

  private handleTouchMove(event: TouchEvent) {
    if (!this.dragTarget) return;

    const touch = event.changedTouches[0];
    const deltaX = touch.screenX - this.touchStartX;
    const deltaY = touch.screenY - this.touchStartY;

    // Lock the gesture axis on first decisive movement so vertical scrolling
    // and tap targets keep working
    if (this.axis === null) {
      if (
        Math.abs(deltaX) < AXIS_LOCK_THRESHOLD &&
        Math.abs(deltaY) < AXIS_LOCK_THRESHOLD
      ) {
        return;
      }
      this.axis =
        Math.abs(deltaX) > Math.abs(deltaY) ? 'horizontal' : 'vertical';
    }

    if (this.axis !== 'horizontal') return;

    // Own the gesture: stop native scroll/text-select while dragging
    event.preventDefault();
    // Any open chart tooltip belongs to a previous interaction — dismiss it
    // so it does not sit on top of the drag feedback
    this.dismissChartTooltips();
    this.rawDeltaX = deltaX;
    this.samples.push({ x: deltaX, t: event.timeStamp });
    if (this.samples.length > 6) this.samples.shift();

    // The content follows the finger exactly, as long as there is a page
    const factor = this.linkTowards(deltaX) ? 1 : RUBBER_BAND_FACTOR;
    this.dragTarget.style.transform = `translate3d(${deltaX * factor}px, 0, 0)`;
  }

  private linkTowards(deltaX: number) {
    return deltaX < 0 ? this.nextLink : this.prevLink;
  }

  // The speed of the finger over its last moves, in px per ms. A finger that
  // rested before it let go has none.
  private velocity(endTime: number) {
    const recent = this.samples.filter(
      (sample) => endTime - sample.t <= VELOCITY_WINDOW,
    );
    if (recent.length < 2) return 0;

    const first = recent[0];
    const last = recent[recent.length - 1];
    return last.t > first.t ? (last.x - first.x) / (last.t - first.t) : 0;
  }

  // Chart tooltips live on document.body (position: fixed) and stay visible
  // after the touch ends until the chart is tapped again. A swipe somewhere
  // else on the page would otherwise leave them stranded over the new content.
  private dismissChartTooltips() {
    const tooltips = document.querySelectorAll<HTMLElement>('.chartjs-tooltip');
    tooltips.forEach((tooltip) => {
      if (tooltip.style.visibility === 'hidden') return;
      tooltip.style.opacity = '0';
      tooltip.style.visibility = 'hidden';
    });
  }

  private handleTouchEnd(event: TouchEvent) {
    if (!this.dragTarget) return;

    const target = this.dragTarget;
    const deltaX = this.rawDeltaX;
    const velocity = this.velocity(event.timeStamp);
    const link = this.linkTowards(deltaX);
    const flick = Math.abs(velocity) > FLICK_VELOCITY;
    const towards = Math.sign(velocity) === Math.sign(deltaX);
    const commit = flick
      ? towards
      : Math.abs(deltaX) > target.clientWidth * COMMIT_DISTANCE_RATIO;

    this.dragTarget = null;
    this.axis = null;

    if (link && deltaX !== 0 && commit) {
      this.turnPage(target, link, deltaX, velocity);
      return;
    }

    // Nothing to spring back if no transform was applied (vertical scroll,
    // tap) — just clear the transition:'none' from touchstart so we don't
    // strand a transitionend listener that would never fire
    if (!target.style.transform) {
      target.style.transition = '';
      return;
    }

    // Spring back to origin; cleanup inline styles once the animation ends
    target.style.transition = SPRING_BACK;
    target.style.transform = '';
    const cleanup = () => {
      target.style.transition = '';
      target.style.transform = '';
      target.removeEventListener('transitionend', cleanup);
      this.pendingSpringBackCleanup = null;
    };
    target.addEventListener('transitionend', cleanup);
    this.pendingSpringBackCleanup = cleanup;
  }

  // The request starts at once, while the content slides out with the speed
  // of the finger. The new page waits for the end of the slide (see
  // turbo:before-render above).
  private turnPage(
    target: HTMLElement,
    link: HTMLAnchorElement,
    deltaX: number,
    velocity: number,
  ) {
    if (isReducedMotion()) {
      link.click();
      return;
    }

    const direction = deltaX < 0 ? -1 : 1;
    const width = target.clientWidth;
    const remaining = width - Math.abs(deltaX);
    const speed = Math.max(Math.abs(velocity), 1);
    const duration = Math.min(
      Math.max(remaining / speed, OUT_DURATION.min),
      OUT_DURATION.max,
    );

    const out = new Promise<void>((resolve) => {
      const done = () => resolve();
      target.addEventListener('transitionend', done, { once: true });
      // A transition that does not run, like one of no distance, ends nothing
      window.setTimeout(done, duration + 50);
    });

    turn = { direction, out };
    document.documentElement.dataset.navSliding = '';
    target.style.transition = `transform ${duration}ms ${EASE_OUT}`;
    target.style.transform = `translate3d(${direction * width}px, 0, 0)`;
    link.click();
  }
}

import { Controller } from '@hotwired/stimulus';
import { isTouchEnabled } from '@/utils/device';

export default class extends Controller<HTMLElement> {
  // A "flick" commits if it travels this far within swipeTimeThreshold
  private readonly swipeThreshold = 50;
  private readonly swipeTimeThreshold = 300;
  // A slow drag commits if it travels at least this fraction of the target's
  // width — otherwise long, deliberate swipes below the flick time would
  // silently spring back
  private readonly commitDistanceRatio = 0.25;
  // How much of the finger travel the content follows while dragging
  private readonly dragFactor = 0.6;
  // Strong dampening when there is no page in that direction (rubber-band)
  private readonly rubberBandFactor = 0.15;
  // Movement (px) required before the gesture locks to horizontal or vertical
  private readonly axisLockThreshold = 10;
  // Touches starting inside this margin from the viewport edge are left to
  // the browser so iOS Safari / Android Chrome edge swipe-back still works
  private readonly edgeMargin = 20;
  private readonly springBackTransition = 'transform 200ms ease-out';
  private readonly dragTargetSelector = '#inner';

  private touchStartX = 0;
  private touchStartY = 0;
  private touchStartTime = 0;
  private rawDeltaX = 0;
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
    // Abort any spring-back still in flight from a previous gesture so its
    // transitionend listener can't leak — the new touch interrupts the
    // transition, which would otherwise never fire
    this.pendingSpringBackCleanup?.();

    const touch = event.changedTouches[0];

    // Leave gestures starting near the viewport edge to the browser so native
    // swipe-back/forward (iOS Safari, Android Chrome) still works
    if (
      touch.clientX < this.edgeMargin ||
      touch.clientX > window.innerWidth - this.edgeMargin
    ) {
      this.dragTarget = null;
      return;
    }

    // Chart canvases handle their own horizontal touch gestures (tooltip
    // crosshair). Leave them alone so dragging the tooltip does not also
    // rubber-band the surrounding page.
    if (event.target instanceof Element && event.target.closest('canvas')) {
      this.dragTarget = null;
      return;
    }

    this.touchStartX = touch.screenX;
    this.touchStartY = touch.screenY;
    this.touchStartTime = Date.now();
    this.rawDeltaX = 0;
    this.axis = null;
    this.dragTarget = document.querySelector<HTMLElement>(
      this.dragTargetSelector,
    );
    this.prevLink =
      document.querySelector<HTMLAnchorElement>('a[data-nav="prev"]');
    this.nextLink =
      document.querySelector<HTMLAnchorElement>('a[data-nav="next"]');

    if (this.dragTarget) {
      // Drop any leftover spring-back transition so the element follows the
      // finger without delay
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
        Math.abs(deltaX) < this.axisLockThreshold &&
        Math.abs(deltaY) < this.axisLockThreshold
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

    const hasTargetLink = deltaX < 0 ? !!this.nextLink : !!this.prevLink;
    const factor = hasTargetLink ? this.dragFactor : this.rubberBandFactor;
    this.dragTarget.style.transform = `translate3d(${deltaX * factor}px, 0, 0)`;
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

  private handleTouchEnd() {
    if (!this.dragTarget) return;

    const target = this.dragTarget;
    const duration = Date.now() - this.touchStartTime;
    const absDeltaX = Math.abs(this.rawDeltaX);
    const link = this.rawDeltaX < 0 ? this.nextLink : this.prevLink;
    const isQuickSwipe =
      absDeltaX > this.swipeThreshold && duration <= this.swipeTimeThreshold;
    const isLongDrag =
      absDeltaX > target.clientWidth * this.commitDistanceRatio;

    this.dragTarget = null;
    this.axis = null;

    if (link && (isQuickSwipe || isLongDrag)) {
      // Turbo will replace the body on navigation, so the transformed element
      // is discarded — no manual cleanup needed
      link.click();
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
    target.style.transition = this.springBackTransition;
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
}

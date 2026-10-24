import { Controller } from '@hotwired/stimulus';
import { openModal } from '@/utils/modal';

// A long press on the period segment opens the timeframe select at once. While
// the live view or today is the current segment, a short tap leads to the
// period instead. Once the period is the current segment, a tap opens the
// select too, and the long press answers the same way rather than doing
// nothing. The sheet loads the address of the select of the period (see
// TimeframeSelectModal).
//
// A finger that moves is a swipe or a scroll, so it opens nothing.
const DELAY = 500;
const TOLERANCE = 10;

export default class extends Controller<HTMLAnchorElement> {
  static readonly values = { href: String };

  declare readonly hrefValue: string;
  declare timer: number | undefined;
  declare start: { x: number; y: number } | null;
  declare pressed: boolean;

  connect() {
    this.pressed = false;
    this.start = null;
  }

  disconnect() {
    this.cancel();
  }

  down(event: PointerEvent) {
    if (event.pointerType === 'mouse') return;

    this.pressed = false;
    this.start = { x: event.clientX, y: event.clientY };
    this.timer = window.setTimeout(() => {
      this.pressed = true;
      this.start = null;
      openModal(this.hrefValue);
    }, DELAY);
  }

  move(event: PointerEvent) {
    if (!this.start) return;

    const dx = Math.abs(event.clientX - this.start.x);
    const dy = Math.abs(event.clientY - this.start.y);
    if (dx > TOLERANCE || dy > TOLERANCE) this.cancel();
  }

  cancel() {
    window.clearTimeout(this.timer);
    this.start = null;
  }

  // The click that ends a long press must not follow the link as well.
  // Turbo leaves a click alone that is prevented already.
  click(event: MouseEvent) {
    if (!this.pressed) return;

    event.preventDefault();
    this.pressed = false;
  }

  // The menu of a link that a long press opens on Android, and in development
  // also on iOS (see application.ts)
  contextmenu(event: Event) {
    event.preventDefault();
  }
}

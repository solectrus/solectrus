import { Controller } from '@hotwired/stimulus';

// Scrolls the active tab into view so it is never clipped on narrow screens
// where the horizontal tab bar overflows. Adjusts scrollLeft only, so the
// page never jumps vertically.
export default class extends Controller<HTMLElement> {
  connect() {
    const active = this.element.querySelector('[aria-current="page"]');
    if (!(active instanceof HTMLElement)) return;

    const { offsetLeft, offsetWidth } = active;
    const { scrollLeft, clientWidth } = this.element;
    const rightEdge = offsetLeft + offsetWidth;

    if (rightEdge > scrollLeft + clientWidth) {
      this.element.scrollLeft = rightEdge - clientWidth;
    } else if (offsetLeft < scrollLeft) {
      this.element.scrollLeft = offsetLeft;
    }
  }
}

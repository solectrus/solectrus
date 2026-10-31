import { Controller } from '@hotwired/stimulus';
import { writeCookie } from '@/utils/cookie';
import { isReducedMotion } from '@/utils/device';
import { EASE_GLIDE } from '@/utils/motion';

// Shows or hides the details of the calculation in the three columns. The
// server renders the choice from a cookie, also when a refresh morphs the
// page. So a click switches the details here at once, and the cookie keeps
// the choice for the next render.
//
// CSS cannot animate the rows between hidden and shown. So the columns grow
// or shrink from their old height to the new one, and the page below follows.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['button', 'columns'];

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly columnsTarget: HTMLElement;

  toggle() {
    const from = this.columnsTarget.offsetHeight;
    const expanded = this.element.toggleAttribute('data-expanded');
    this.buttonTarget.setAttribute('aria-expanded', String(expanded));

    // The default needs no cookie
    writeCookie('car_comparison_details', expanded ? 'true' : null);

    if (isReducedMotion()) return;

    const to = this.columnsTarget.offsetHeight;
    this.columnsTarget.animate(
      [
        { height: `${from}px`, overflow: 'clip', opacity: 0.4 },
        { height: `${to}px`, overflow: 'clip', opacity: 1 },
      ],
      { duration: 300, easing: EASE_GLIDE },
    );
  }
}

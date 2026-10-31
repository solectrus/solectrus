import { Controller } from '@hotwired/stimulus';
import { writeCookie } from '@/utils/cookie';
import { isReducedMotion } from '@/utils/device';
import { EASE_GLIDE } from '@/utils/motion';

// Adds the car without PV to the comparison or takes it away, and shows or
// hides the details of the calculation in the columns. The server renders
// each choice from a cookie, also when a refresh morphs the page. So a click
// switches here at once, and the cookie keeps the choice for the next render.
//
// CSS cannot animate the rows of the details between hidden and shown. So
// the columns grow or shrink from their old height to the new one, and the
// page below follows. The rows glide to their new places: the rows that go
// fade out first, and the rows that come fade in (see
// Car::ComparisonColumns::Component#visibility). The car without PV animates
// with CSS alone (see Car::ComparisonFormat::MOTION).
const DURATION = 300;

// The top of a row, undefined while it hides
const topOf = (row: HTMLElement) => row.getClientRects()[0]?.top;

export default class extends Controller<HTMLElement> {
  static readonly targets = ['button', 'columns', 'details'];

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly columnsTarget: HTMLElement;
  declare readonly detailsTarget: HTMLElement;

  private toggling = false;

  // CSS shows the parts of the car without PV, and the charts read the
  // attribute when they change (see showsWithoutPv in comparison_chart_base)
  toggleWithoutPv({ currentTarget }: Event) {
    const withoutPv = this.element.toggleAttribute('data-without-pv');
    (currentTarget as HTMLElement).setAttribute(
      'aria-pressed',
      String(withoutPv),
    );

    // The default needs no cookie
    writeCookie('car_comparison_without_pv', withoutPv ? 'true' : null);

    this.dispatch('without-pv', { target: document });
  }

  async toggle() {
    if (this.toggling) return;

    const expanded = !this.detailsTarget.hasAttribute('data-expanded');
    this.buttonTarget.setAttribute('aria-expanded', String(expanded));

    // The default needs no cookie
    writeCookie('car_comparison_details', expanded ? 'true' : null);

    if (isReducedMotion()) {
      this.detailsTarget.toggleAttribute('data-expanded', expanded);
      return;
    }

    this.toggling = true;

    // An empty row only keeps the height of its slot, so it needs no motion
    const rows = [
      ...this.columnsTarget.querySelectorAll<HTMLElement>(
        'tr:not([aria-hidden])',
      ),
    ];

    // The rows that go fade out first and stay faded until they hide
    const going = expanded ? 'summary' : 'detail';
    const fadeOuts = rows
      .filter(
        (row) => row.dataset.details === going && topOf(row) !== undefined,
      )
      .map((row) =>
        row.animate([{ opacity: 1 }, { opacity: 0 }], {
          duration: DURATION / 2,
          easing: 'ease-out',
          fill: 'forwards',
        }),
      );
    await Promise.all(fadeOuts.map((animation) => animation.finished));

    const before = rows.map(topOf);
    const from = this.columnsTarget.offsetHeight;
    this.detailsTarget.toggleAttribute('data-expanded', expanded);
    fadeOuts.forEach((animation) => animation.cancel());

    this.glide(rows, before, from);
    this.toggling = false;
  }

  // The columns grow or shrink from their old height to the new one, and the
  // page below follows. A row that stays glides from its old place to the
  // new one, and a row that comes fades in there. All new places are read
  // before the first animation, so the animations force no layout.
  private glide(
    rows: HTMLElement[],
    before: (number | undefined)[],
    from: number,
  ) {
    const after = rows.map(topOf);
    const to = this.columnsTarget.offsetHeight;
    const options = { duration: DURATION, easing: EASE_GLIDE };

    this.columnsTarget.animate(
      [
        { height: `${from}px`, overflow: 'clip' },
        { height: `${to}px`, overflow: 'clip' },
      ],
      options,
    );

    rows.forEach((row, index) => {
      const [old, now] = [before[index], after[index]];
      if (now === undefined) return;

      if (old === undefined)
        row.animate([{ opacity: 0 }, { opacity: 1 }], options);
      else if (old !== now)
        row.animate(
          [{ transform: `translateY(${old - now}px)` }, { transform: 'none' }],
          options,
        );
    });
  }
}

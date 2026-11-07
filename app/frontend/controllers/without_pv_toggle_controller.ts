import { Controller } from '@hotwired/stimulus';
import { writeCookie } from '@/utils/cookie';

// Adds the column without PV to a comparison or takes it away: the car
// without PV (see Car::ComparisonPage::Component), or the heat pump without
// PV (see Heatpump::ComparisonPage::Component). CSS shows its parts from the
// attribute of the element (see Car::ComparisonFormat::MOTION), and the
// charts draw it again on the event (see showsWithoutPv in
// comparison_chart_base). The server renders the choice from the cookie,
// also when a refresh morphs the page.
export default class extends Controller<HTMLElement> {
  static readonly values = { cookie: String };

  declare readonly cookieValue: string;

  toggle({ currentTarget }: Event) {
    const withoutPv = this.element.toggleAttribute('data-without-pv');
    (currentTarget as HTMLElement).setAttribute(
      'aria-pressed',
      String(withoutPv),
    );

    // The default needs no cookie
    writeCookie(this.cookieValue, withoutPv ? 'true' : null);

    this.dispatch('change', { target: document });
  }
}

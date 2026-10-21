import { Controller, type ActionEvent } from '@hotwired/stimulus';

// A phone shows one of the two cards of the car page, the charging or the
// driving: the card of the pressed button (see the stats). Each chart renders
// the toggle for its sensor, so the card follows the chart. A tap presses the
// button at once and loads the main chart of its card.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['button', 'chart'];

  declare readonly buttonTargets: HTMLButtonElement[];
  declare readonly chartTargets: HTMLElement[];

  show(event: ActionEvent) {
    const pressed = event.currentTarget as HTMLButtonElement;
    if (pressed.getAttribute('aria-pressed') === 'true') return;

    this.buttonTargets.forEach((button) =>
      button.setAttribute('aria-pressed', String(button === pressed)),
    );

    // A card without a chart for the timeframe has a plain block instead
    const chart = this.chartTargets.find(
      (target) => target.dataset.carCard === event.params.card,
    );
    if (chart instanceof HTMLAnchorElement) chart.click();
  }
}

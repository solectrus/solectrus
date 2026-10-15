import { Controller } from '@hotwired/stimulus';

// Live-updates the value labels while a slider is being dragged. The form is
// submitted on release (change event) by the shared `auto-submit` controller,
// which recomputes and re-renders the surrounding Turbo frame and remembers the
// values in per-browser cookies, so the next page load renders them directly.
export default class extends Controller {
  static targets = ['periodInput', 'periodValue', 'rateInput', 'rateValue'];

  declare readonly periodInputTarget: HTMLInputElement;
  declare readonly periodValueTarget: HTMLElement;
  declare readonly rateInputTarget: HTMLInputElement;
  declare readonly rateValueTarget: HTMLElement;

  updatePeriod() {
    this.periodValueTarget.textContent = this.periodInputTarget.value;
  }

  updateRate() {
    this.rateValueTarget.textContent = Number(
      this.rateInputTarget.value,
    ).toLocaleString(document.documentElement.lang || 'en', {
      minimumFractionDigits: 1,
      maximumFractionDigits: 1,
    });
  }
}

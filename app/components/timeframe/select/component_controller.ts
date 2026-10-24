import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

// The tabs and the timeframe of a wide screen in landscape. Below it, the
// period segment of a phone opens the select, and its fields come first.
const wideScreen = window.matchMedia(
  '(min-width: 64rem) and (orientation: landscape)',
);

// Connects to data-controller="timeframe--select--component"
export default class extends Controller<HTMLElement> {
  static readonly values = {
    // The address of the page with ":timeframe" in place of the timeframe
    urlTemplate: String,
    id: String,
  };

  declare readonly urlTemplateValue: string;
  declare readonly idValue: string;

  // Mapping from timeframe ID to picker button for auto-open.
  // Relative timeframes (hours, days, months, years) are not listed
  // because their options are displayed inline as buttons.
  private readonly pickerConfig: Record<string, string> = {
    day: 'day-picker-input-button',
    week: 'week-picker-input-button',
    month: 'month-picker-input-button',
    year: 'year-picker-input-button',
    range: 'range-picker-input-button',
  };

  connect(): void {
    this.autoOpenPicker();
  }

  handlePickerSelected(event: CustomEvent): void {
    const { value } = event.detail;

    if (value) this.visit(value);
  }

  // The field of a picker selects the period it shows. The button lies in the
  // summary of the picker, which must not open.
  choose(event: Event & { params: { value: string | number } }): void {
    event.preventDefault();
    this.visit(String(event.params.value));
  }

  private visit(timeframe: string): void {
    Turbo.visit(this.urlTemplateValue.replace(':timeframe', timeframe));
  }

  // A phone shows the fields first, which an open picker would cover
  private autoOpenPicker(): void {
    if (!this.idValue || !wideScreen.matches) return;

    const buttonId = this.pickerConfig[this.idValue];
    if (!buttonId) return;

    // Wait for next frame to ensure all pickers are fully initialized
    requestAnimationFrame(() => {
      this.openPicker(buttonId);
    });
  }

  private openPicker(buttonId: string): void {
    const button = document.getElementById(buttonId);

    if (button) {
      button.click();
    }
  }
}

import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

// Connects to data-controller="timeframe-select--component"
export default class extends Controller<HTMLElement> {
  static readonly values = {
    baseUrl: String,
    id: String,
  };

  declare readonly baseUrlValue: string;
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

    if (value) {
      Turbo.visit(`${this.baseUrlValue}/${value}`);
    }
  }

  private autoOpenPicker(): void {
    if (!this.idValue) return;

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

import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

type PickerType = 'day' | 'week' | 'month' | 'year' | 'range' | 'relative';

// Connects to data-controller="timeframe-select--component"
export default class extends Controller<HTMLElement> {
  static readonly values = {
    baseUrl: String,
    id: String,
  };

  declare readonly baseUrlValue: string;
  declare readonly idValue: string;

  // Unified mapping from timeframe ID to picker config
  private readonly pickerConfig: Record<
    string,
    { type: PickerType; buttonId: string }
  > = {
    day: { type: 'day', buttonId: 'day-picker-input-button' },
    week: { type: 'week', buttonId: 'week-picker-input-button' },
    month: { type: 'month', buttonId: 'month-picker-input-button' },
    year: { type: 'year', buttonId: 'year-picker-input-button' },
    range: { type: 'range', buttonId: 'range-picker-input-button' },
    hours: { type: 'relative', buttonId: 'relative-picker-input-button' },
    days: { type: 'relative', buttonId: 'relative-picker-input-button' },
    months: { type: 'relative', buttonId: 'relative-picker-input-button' },
    years: { type: 'relative', buttonId: 'relative-picker-input-button' },
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

    const config = this.pickerConfig[this.idValue];
    if (!config) return;

    // Wait for next frame to ensure all pickers are fully initialized
    requestAnimationFrame(() => {
      this.openPicker(config.buttonId);
    });
  }

  private openPicker(buttonId: string): void {
    const button = document.getElementById(buttonId);

    if (button) {
      button.click();
    }
  }
}

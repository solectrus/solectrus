import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

// Connects to data-controller="timeframe-select--component"
export default class extends Controller<HTMLElement> {
  static readonly values = {
    baseUrl: String,
  };

  declare readonly baseUrlValue: string;

  handlePickerSelected(event: CustomEvent): void {
    const { value } = event.detail;

    if (value) {
      Turbo.visit(`${this.baseUrlValue}/${value}`);
    }
  }
}

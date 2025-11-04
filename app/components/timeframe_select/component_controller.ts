import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

import './component.css';

// Connects to data-controller="timeframe-select--component"
export default class extends Controller<HTMLElement> {
  static readonly targets = ['predefinedSelect'];
  static readonly values = {
    baseUrl: String,
    basePath: String,
  };

  declare readonly predefinedSelectTarget: HTMLSelectElement;
  declare readonly hasPredefinedSelectTarget: boolean;
  declare readonly baseUrlValue: string;
  declare readonly basePathValue: string;

  connect() {
    this.setupPickerListeners();
  }

  private setupPickerListeners(): void {
    const pickers = [
      {
        selector: 'input[name="day-picker-input"]',
        handler: () => this.submitDay(),
      },
      {
        selector: 'input[name="week-picker-input"]',
        handler: () => this.submitWeek(),
      },
      {
        selector: 'input[name="month-picker-input"]',
        handler: () => this.submitMonth(),
      },
      {
        selector: 'select[name="year-picker-input"]',
        handler: () => this.submitYear(),
      },
      {
        selector: 'input[name="range-picker-input"]',
        handler: () => this.submitDateRange(),
      },
    ];

    for (const { selector, handler } of pickers) {
      const element = document.querySelector(selector) as HTMLInputElement;
      element?.addEventListener('change', handler);
    }
  }

  disconnect() {
    // Nothing to clean up anymore
  }

  submitYear() {
    this.submitPickerValue('select[name="year-picker-input"]', /^\d{4}$/);
  }

  submitMonth() {
    this.submitPickerValue('input[name="month-picker-input"]', /^\d{4}-\d{2}$/);
  }

  submitWeek() {
    this.submitPickerValue('input[name="week-picker-input"]', /^\d{4}-W\d{2}$/);
  }

  submitDay() {
    this.submitPickerValue(
      'input[name="day-picker-input"]',
      /^\d{4}-\d{2}-\d{2}$/,
    );
  }

  submitDateRange() {
    const input = document.querySelector(
      'input[name="range-picker-input"]',
    ) as HTMLInputElement;
    const value = input?.value || '';

    // Pattern: YYYY-MM-DD..YYYY-MM-DD
    if (/^\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2}$/.exec(value)) {
      Turbo.visit(`${this.baseUrlValue}/${value}`);
    }
  }

  submitPredefined() {
    const value = this.predefinedSelectTarget?.value;
    if (value) {
      Turbo.visit(`${this.basePathValue}/${value}`);
    }
  }

  private submitPickerValue(selector: string, pattern: RegExp): void {
    const input = document.querySelector(selector) as
      | HTMLInputElement
      | HTMLSelectElement;
    const value = input?.value || '';

    if (pattern.exec(value)) {
      Turbo.visit(`${this.basePathValue}/${value}`);
    }
  }
}

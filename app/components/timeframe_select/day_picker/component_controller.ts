import { Controller } from '@hotwired/stimulus';
import { DateTime } from 'luxon';

import AirDatepicker from 'air-datepicker';
import type { AirDatepickerLocale } from 'air-datepicker';
import localeDE from 'air-datepicker/locale/de';
import localeEN from 'air-datepicker/locale/en';
import 'air-datepicker/air-datepicker.css';

import './component.css';

// Get locale based on browser language
function getDatepickerLocale(): AirDatepickerLocale {
  const browserLang = navigator.language.toLowerCase();
  return browserLang.startsWith('de') ? localeDE : localeEN;
}

// Helper function to format Date to YYYY-MM-DD
function formatDate(date: Date): string {
  return DateTime.fromJSDate(date).toISODate()!;
}

export default class extends Controller<HTMLElement> {
  static readonly targets = [
    'hiddenInput',
    'displayButton',
    'displayText',
    'pickerContainer',
  ];

  static readonly values = {
    value: String,
    endingValue: String,
    minDate: String,
    maxDate: String,
    name: String,
    range: Boolean,
  };

  declare readonly hiddenInputTarget: HTMLInputElement;
  declare readonly displayButtonTarget: HTMLButtonElement;
  declare readonly displayTextTarget: HTMLElement;
  declare readonly pickerContainerTarget: HTMLElement;

  declare valueValue: string;
  declare endingValueValue: string;
  declare minDateValue: string;
  declare maxDateValue: string;
  declare nameValue: string;
  declare rangeValue: boolean;

  private datepicker?: AirDatepicker<HTMLInputElement>;
  private locale!: string;

  connect() {
    // Get browser locale from document or fallback to 'en'
    this.locale =
      document.documentElement.lang || navigator.language.split('-')[0] || 'en';

    this.initializeDatepicker();

    // Close dropdown when pressing Escape (use keyup to match modal's event)
    document.addEventListener('keyup', this.handleEscape, true);

    // Close this picker when another picker opens
    document.addEventListener('picker:open', this.handleOtherPickerOpen);
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside);
    document.removeEventListener('keyup', this.handleEscape, true);
    document.removeEventListener('picker:open', this.handleOtherPickerOpen);
    this.datepicker?.destroy();
  }

  toggle(event: Event) {
    event.stopPropagation();
    event.preventDefault();

    if (this.datepicker?.visible) {
      this.close();
    } else {
      this.open();
    }
  }

  private open() {
    this.datepicker?.show();

    // Notify other pickers to close
    document.dispatchEvent(
      new CustomEvent('picker:open', { detail: { picker: this.element } }),
    );

    requestAnimationFrame(() => {
      document.addEventListener('click', this.handleClickOutside);
      this.adjustDatepickerWidth();
    });
  }

  close() {
    if (this.datepicker?.visible) {
      this.datepicker.hide();
    }
    document.removeEventListener('click', this.handleClickOutside);
  }

  private readonly handleClickOutside = (event: Event): void => {
    const datepickerElement = this.datepicker?.$datepicker;
    if (!datepickerElement) return;

    // Close if click is outside the datepicker AND outside the display button
    if (
      !datepickerElement.contains(event.target as Node) &&
      !this.displayButtonTarget.contains(event.target as Node)
    ) {
      this.close();
    }
  };

  private readonly handleEscape = (event: KeyboardEvent): void => {
    if (event.key === 'Escape' && this.datepicker?.visible) {
      event.preventDefault();
      this.close();
    }
  };

  private readonly handleOtherPickerOpen = (event: Event): void => {
    const customEvent = event as CustomEvent;
    // Close this picker if another picker opened
    if (customEvent.detail?.picker !== this.element) {
      this.close();
    }
  };

  private initializeDatepicker(): void {
    const selectedDates = this.rangeValue
      ? this.parseDateRange()
      : this.parseDate(this.valueValue);

    // Create a hidden input element for AirDatepicker
    const input = document.createElement('input');
    input.type = 'text';
    input.readOnly = true;
    input.style.position = 'absolute';
    input.style.opacity = '0';
    input.style.pointerEvents = 'none';
    this.pickerContainerTarget.appendChild(input);

    this.datepicker = new AirDatepicker(input, {
      locale: getDatepickerLocale(),
      dateFormat: 'dd.MM.yyyy',
      range: this.rangeValue,
      multipleDatesSeparator: ' - ',
      minDate: this.minDateValue ? new Date(this.minDateValue) : undefined,
      maxDate: this.maxDateValue ? new Date(this.maxDateValue) : new Date(),
      selectedDates: selectedDates,
      autoClose: false, // Keep open, will close automatically on navigation
      container: this.element,
      position: 'top left',
      keyboardNav: false,
      moveToOtherMonthsOnSelect: false,
      onShow: () => {
        // Navigate to the month of the first selected date when opening
        if (selectedDates && selectedDates.length > 0) {
          this.datepicker?.setViewDate(selectedDates[0]);
        }
      },
      onSelect: ({ date }) => {
        if (this.rangeValue) {
          // For ranges, only trigger when both dates are selected
          if (Array.isArray(date) && date.length === 2) {
            this.handleRangeSelect(date);
          }
        } else {
          // For single dates, trigger immediately
          if (date && !Array.isArray(date)) {
            this.handleDaySelect(date);
          }
        }
      },
    });
  }

  private handleDaySelect(date: Date): void {
    const dayValue = formatDate(date);
    this.valueValue = dayValue;
    this.hiddenInputTarget.value = dayValue;

    // Update display text
    this.updateDisplayText(date);

    // Dispatch change event (picker will close automatically on navigation)
    this.hiddenInputTarget.dispatchEvent(
      new Event('change', { bubbles: true }),
    );
  }

  private handleRangeSelect(dates: Date[]): void {
    const startDate = formatDate(dates[0]);
    const endDate = formatDate(dates[1]);

    this.valueValue = startDate;
    this.endingValueValue = endDate;
    this.hiddenInputTarget.value = `${startDate}..${endDate}`;

    // Update display text
    this.updateDisplayTextRange(dates[0], dates[1]);

    // Dispatch change event (picker will close automatically on navigation)
    this.hiddenInputTarget.dispatchEvent(
      new Event('change', { bubbles: true }),
    );
  }

  private updateDisplayText(date: Date): void {
    const dt = DateTime.fromJSDate(date);
    this.displayTextTarget.textContent = dt.toFormat('dd.MM.yyyy');
  }

  private updateDisplayTextRange(startDate: Date, endDate: Date): void {
    const start = DateTime.fromJSDate(startDate);
    const end = DateTime.fromJSDate(endDate);
    this.displayTextTarget.textContent = `${start.toFormat('dd.MM.yyyy')} - ${end.toFormat('dd.MM.yyyy')}`;
  }

  private parseDate(dateValue: string): Date[] | undefined {
    if (!dateValue || !/^\d{4}-\d{2}-\d{2}$/.exec(dateValue)) return undefined;
    return [new Date(dateValue)];
  }

  private parseDateRange(): Date[] | undefined {
    if (!this.valueValue || !this.endingValueValue) return undefined;
    return [new Date(this.valueValue), new Date(this.endingValueValue)];
  }

  private adjustDatepickerWidth(): void {
    const datepicker = this.datepicker?.$datepicker;
    if (!datepicker) return;

    const width = `${this.displayButtonTarget.offsetWidth}px`;
    datepicker.style.width = width;
    datepicker.style.minWidth = width;
    datepicker.style.maxWidth = width;
  }
}

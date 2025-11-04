import { Controller } from '@hotwired/stimulus';
import { DateTime } from 'luxon';

export default class extends Controller<HTMLElement> {
  static readonly targets = [
    'hiddenInput',
    'displayButton',
    'displayText',
    'dropdown',
    'yearDisplay',
    'monthCell',
    'prevYearButton',
    'nextYearButton',
  ];

  static readonly values = {
    value: String,
    minDate: String,
    maxDate: String,
    initialYear: Number,
    name: String,
  };

  declare readonly hiddenInputTarget: HTMLInputElement;
  declare readonly displayButtonTarget: HTMLButtonElement;
  declare readonly displayTextTarget: HTMLElement;
  declare readonly dropdownTarget: HTMLElement;
  declare readonly yearDisplayTarget: HTMLElement;
  declare readonly monthCellTargets: HTMLButtonElement[];
  declare readonly prevYearButtonTarget: HTMLButtonElement;
  declare readonly nextYearButtonTarget: HTMLButtonElement;

  declare valueValue: string;
  declare minDateValue: string;
  declare maxDateValue: string;
  declare initialYearValue: number;
  declare nameValue: string;

  private currentYear!: number;
  private selectedMonth: DateTime | null = null;
  private locale!: string;

  connect() {
    // Get browser locale from document or fallback to 'en'
    this.locale =
      document.documentElement.lang || navigator.language.split('-')[0] || 'en';

    // Initialize current year
    this.currentYear = this.initialYearValue || DateTime.now().year;

    // Initialize selected month with validation
    if (this.valueValue) {
      const parsed = DateTime.fromISO(this.valueValue + '-01');
      if (parsed.isValid) {
        this.selectedMonth = parsed;
      }
    }

    this.renderMonths();

    // Close dropdown when pressing Escape (use keyup to match modal's event)
    document.addEventListener('keyup', this.handleEscape, true);

    // Close this picker when another picker opens
    document.addEventListener('picker:open', this.handleOtherPickerOpen);
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside);
    document.removeEventListener('keyup', this.handleEscape, true);
    document.removeEventListener('picker:open', this.handleOtherPickerOpen);
  }

  toggle(event: Event) {
    event.stopPropagation();
    event.preventDefault();
    const wasHidden = this.dropdownTarget.classList.contains('hidden');

    if (wasHidden) {
      this.open();
    } else {
      this.close();
    }
  }

  private open() {
    // Show dropdown
    this.dropdownTarget.classList.remove('hidden');

    // Set dropdown width to match button width
    const buttonWidth = this.displayButtonTarget.offsetWidth;
    this.dropdownTarget.style.width = `${buttonWidth}px`;

    // Notify other pickers to close
    document.dispatchEvent(
      new CustomEvent('picker:open', { detail: { picker: this.element } }),
    );

    requestAnimationFrame(() => {
      document.addEventListener('click', this.handleClickOutside);
    });
  }

  close() {
    this.dropdownTarget.classList.add('hidden');
    document.removeEventListener('click', this.handleClickOutside);
  }

  private readonly handleClickOutside = (event: Event): void => {
    // Close if click is outside the dropdown AND outside the display button
    if (
      !this.dropdownTarget.contains(event.target as Node) &&
      !this.displayButtonTarget.contains(event.target as Node)
    ) {
      this.close();
    }
  };

  private readonly handleEscape = (event: KeyboardEvent): void => {
    if (
      event.key === 'Escape' &&
      !this.dropdownTarget.classList.contains('hidden')
    ) {
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

  previousYear() {
    this.currentYear--;
    this.renderMonths();
  }

  nextYear() {
    this.currentYear++;
    this.renderMonths();
  }

  selectMonth(event: Event) {
    const button = event.currentTarget as HTMLButtonElement;
    const monthStr = button.dataset.month;
    if (!monthStr) return;

    const month = DateTime.fromISO(monthStr);
    if (!month.isValid) return;

    this.selectedMonth = month;
    this.valueValue = month.toFormat('yyyy-MM');
    this.hiddenInputTarget.value = this.valueValue;

    // Update display
    this.displayTextTarget.textContent = month.toFormat('MMMM yyyy', {
      locale: this.locale,
    });

    // Dispatch change event (picker will close automatically on navigation)
    this.hiddenInputTarget.dispatchEvent(
      new Event('change', { bubbles: true }),
    );

    this.renderMonths();
  }

  private renderMonths() {
    // Update year display
    this.yearDisplayTarget.textContent = this.currentYear.toString();

    // Get min/max dates for validation
    const minDate = this.minDateValue
      ? DateTime.fromISO(this.minDateValue)
      : null;
    const maxDate = this.maxDateValue
      ? DateTime.fromISO(this.maxDateValue)
      : null;

    // Get month names from browser locale
    const monthFormatter = new Intl.DateTimeFormat(this.locale, {
      month: 'short',
    });

    // Render 12 months
    this.monthCellTargets.forEach((cell, index) => {
      const monthNum = index + 1;
      const month = DateTime.fromObject({
        year: this.currentYear,
        month: monthNum,
      });
      const isSelected =
        this.selectedMonth?.year === this.currentYear &&
        this.selectedMonth?.month === monthNum;

      // Check if month is disabled (outside min/max range)
      const isDisabled =
        (minDate && month < minDate.startOf('month')) ||
        (maxDate && month > maxDate.startOf('month')) ||
        false;

      // Set month data attribute
      cell.dataset.month = month.toFormat('yyyy-MM');

      // Set text content using Intl
      const monthDate = new Date(this.currentYear, index, 1);
      cell.textContent = monthFormatter.format(monthDate);

      // Reset classes
      cell.className =
        'text-sm p-2 rounded text-center focus:outline-none focus:ring-2 focus:ring-indigo-500';

      // Apply styling based on state
      if (isDisabled) {
        cell.className +=
          ' text-gray-300 dark:text-gray-600 cursor-not-allowed';
        cell.disabled = true;
      } else {
        cell.disabled = false;
        cell.className += ' hover:bg-indigo-100 dark:hover:bg-indigo-900';

        if (isSelected) {
          cell.className +=
            ' bg-indigo-600 text-white hover:bg-indigo-700 dark:hover:bg-indigo-700';
        } else {
          cell.className += ' text-gray-900 dark:text-white';
        }
      }
    });

    // Disable year navigation buttons if at limits
    if (minDate) {
      this.prevYearButtonTarget.disabled = this.currentYear <= minDate.year;
    }
    if (maxDate) {
      this.nextYearButtonTarget.disabled = this.currentYear >= maxDate.year;
    }
  }
}

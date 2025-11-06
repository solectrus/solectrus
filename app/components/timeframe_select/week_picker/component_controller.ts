import { Controller } from '@hotwired/stimulus';
import { DateTime } from 'luxon';

export default class extends Controller<HTMLElement> {
  static readonly targets = [
    'details',
    'hiddenInput',
    'displayButton',
    'displayText',
    'modal',
    'yearDisplay',
    'weekGrid',
    'prevYearButton',
    'nextYearButton',
  ];

  static readonly values = {
    value: String,
    minDate: String,
    maxDate: String,
    initialYear: Number,
    name: String,
    monthRowClass: String,
    monthLabelClass: String,
    weekButtonBaseClass: String,
    weekButtonDisabledClass: String,
    weekButtonHoverClass: String,
    weekButtonSelectedClass: String,
    weekButtonDefaultClass: String,
    emptySlotClass: String,
  };

  declare readonly detailsTarget: HTMLDetailsElement;
  declare readonly hiddenInputTarget: HTMLInputElement;
  declare readonly displayButtonTarget: HTMLButtonElement;
  declare readonly displayTextTarget: HTMLElement;
  declare readonly modalTarget: HTMLElement;
  declare readonly yearDisplayTarget: HTMLElement;
  declare readonly weekGridTarget: HTMLElement;
  declare readonly prevYearButtonTarget: HTMLButtonElement;
  declare readonly nextYearButtonTarget: HTMLButtonElement;

  declare valueValue: string;
  declare minDateValue: string;
  declare maxDateValue: string;
  declare initialYearValue: number;
  declare nameValue: string;
  declare monthRowClassValue: string;
  declare monthLabelClassValue: string;
  declare weekButtonBaseClassValue: string;
  declare weekButtonDisabledClassValue: string;
  declare weekButtonHoverClassValue: string;
  declare weekButtonSelectedClassValue: string;
  declare weekButtonDefaultClassValue: string;
  declare emptySlotClassValue: string;

  private currentYear!: number;
  private selectedWeek: string | null = null;
  private locale!: string;
  private abortController?: AbortController;

  connect() {
    // Get browser locale from document or fallback to 'en'
    this.locale =
      document.documentElement.lang || navigator.language.split('-')[0] || 'en';

    // Initialize current year
    this.currentYear = this.initialYearValue || DateTime.now().year;

    // Initialize selected week with validation
    if (this.valueValue && this.isValidWeekFormat(this.valueValue)) {
      this.selectedWeek = this.valueValue;
    }

    this.renderWeeks();

    // Handle ESC key
    document.addEventListener('keydown', this.handleKeydown, true);

    // Close this picker when another picker opens
    document.addEventListener('picker:open', this.handleOtherPickerOpen);
  }

  disconnect() {
    // Abort all button event listeners
    this.abortController?.abort();

    document.removeEventListener('keydown', this.handleKeydown, true);
    document.removeEventListener('picker:open', this.handleOtherPickerOpen);
  }

  // Handle toggle event from details element
  handleToggle() {
    if (this.detailsTarget.open) {
      this.open();
    }
  }

  private open() {
    // Details is already open via native behavior

    // Notify other pickers to close
    document.dispatchEvent(
      new CustomEvent('picker:open', { detail: { picker: this.element } }),
    );
  }

  close() {
    this.detailsTarget.removeAttribute('open');
  }

  private readonly handleKeydown = (event: KeyboardEvent): void => {
    // Only handle when picker is open
    if (!this.detailsTarget.open) {
      return;
    }

    // Handle ESC key
    if (event.key === 'Escape') {
      event.preventDefault();
      event.stopPropagation(); // Prevent ESC from reaching the modal dialog
      this.close();
      return;
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
    this.renderWeeks();
  }

  nextYear() {
    this.currentYear++;
    this.renderWeeks();
  }

  selectWeek(event: Event) {
    const button = event.currentTarget as HTMLButtonElement;
    const weekStr = button.dataset.week;
    if (!weekStr) return;

    this.selectedWeek = weekStr;
    this.valueValue = weekStr;

    // Fire event for immediate navigation
    window.dispatchEvent(
      new CustomEvent('picker:selected', {
        detail: { value: this.valueValue, isRange: false },
      }),
    );
  }

  private renderWeeks() {
    // Update year display
    this.yearDisplayTarget.textContent = this.currentYear.toString();

    // Get min/max dates for validation
    const minDate = this.minDateValue
      ? DateTime.fromISO(this.minDateValue)
      : null;
    const maxDate = this.maxDateValue
      ? DateTime.fromISO(this.maxDateValue)
      : null;

    // Abort old button listeners before re-rendering
    this.abortController?.abort();
    this.abortController = new AbortController();

    // Clear existing weeks
    this.weekGridTarget.innerHTML = '';

    // Group weeks by month
    // A week belongs to a month if Thursday (day 4) of that week is in that month
    // This follows ISO 8601 week date system
    const weeksByMonth: Map<number, number[]> = new Map();

    // Get all weeks in this year
    const weeksInYear = DateTime.fromObject({
      weekYear: this.currentYear,
      weekNumber: 52,
    }).weeksInWeekYear;

    // For each week, determine which month it belongs to (based on Thursday)
    for (let weekNum = 1; weekNum <= weeksInYear; weekNum++) {
      const weekDate = DateTime.fromObject({
        weekYear: this.currentYear,
        weekNumber: weekNum,
      });
      // Thursday is day 4 of the week
      const thursday = weekDate.set({ weekday: 4 });
      const monthOfThursday = thursday.month;

      if (!weeksByMonth.has(monthOfThursday)) {
        weeksByMonth.set(monthOfThursday, []);
      }
      weeksByMonth.get(monthOfThursday)!.push(weekNum);
    }

    // Render each month
    for (let month = 1; month <= 12; month++) {
      const weeks = weeksByMonth.get(month) || [];

      // Create month row with fixed 6 columns (month + 5 week slots)
      const monthRow = document.createElement('div');
      monthRow.className = this.monthRowClassValue;

      // Month label
      const monthLabel = document.createElement('div');
      monthLabel.className = this.monthLabelClassValue;
      const monthDate = DateTime.fromObject({
        year: this.currentYear,
        month: month,
      });
      monthLabel.textContent = monthDate.toFormat('MMMM', {
        locale: this.locale,
      });
      monthRow.appendChild(monthLabel);

      // Add week buttons (max 5 slots)
      for (let i = 0; i < 5; i++) {
        if (i < weeks.length) {
          const weekNum = weeks[i];
          const weekDate = DateTime.fromObject({
            weekYear: this.currentYear,
            weekNumber: weekNum,
          });
          const weekStr = weekDate.toFormat("kkkk-'W'WW");
          const isSelected = this.selectedWeek === weekStr;

          // Check if week is disabled (outside min/max range)
          const weekStart = weekDate.startOf('week');
          const weekEnd = weekDate.endOf('week');
          const isDisabled =
            (minDate && weekEnd < minDate) ||
            (maxDate && weekStart > maxDate) ||
            false;

          // Create button
          const button = document.createElement('button');
          button.type = 'button';
          button.dataset.week = weekStr;
          const weekAbbr = this.locale === 'de' ? 'KW' : 'CW';
          button.textContent = `${weekAbbr} ${weekNum.toString().padStart(2, '0')}`;
          button.className = this.weekButtonBaseClassValue;

          if (isDisabled) {
            button.className += ` ${this.weekButtonDisabledClassValue}`;
            button.disabled = true;
          } else {
            button.disabled = false;
            button.className += ` ${this.weekButtonHoverClassValue}`;
            button.addEventListener(
              'click',
              (e) => {
                e.stopPropagation();
                this.selectWeek(e);
              },
              { signal: this.abortController?.signal },
            );

            if (isSelected) {
              button.className += ` ${this.weekButtonSelectedClassValue}`;
            } else {
              button.className += ` ${this.weekButtonDefaultClassValue}`;
            }
          }

          monthRow.appendChild(button);
        } else {
          // Empty cell for alignment
          const emptyCell = document.createElement('div');
          emptyCell.className = this.emptySlotClassValue;
          monthRow.appendChild(emptyCell);
        }
      }

      this.weekGridTarget.appendChild(monthRow);
    }

    // Disable year navigation buttons if at limits
    if (minDate) {
      this.prevYearButtonTarget.disabled = this.currentYear <= minDate.year;
    }
    if (maxDate) {
      this.nextYearButtonTarget.disabled = this.currentYear >= maxDate.year;
    }
  }

  private isValidWeekFormat(value: string): boolean {
    // Check format YYYY-Wnn
    if (!/^\d{4}-W\d{2}$/.test(value)) {
      return false;
    }

    // Validate it's a valid ISO week date
    const parsed = DateTime.fromISO(value);
    return parsed.isValid;
  }
}

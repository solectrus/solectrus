import { Controller } from '@hotwired/stimulus';
import { DateTime } from 'luxon';

export default class extends Controller<HTMLElement> {
  static readonly targets = [
    'hiddenInput',
    'displayButton',
    'displayText',
    'dropdown',
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
  };

  declare readonly hiddenInputTarget: HTMLInputElement;
  declare readonly displayButtonTarget: HTMLButtonElement;
  declare readonly displayTextTarget: HTMLElement;
  declare readonly dropdownTarget: HTMLElement;
  declare readonly yearDisplayTarget: HTMLElement;
  declare readonly weekGridTarget: HTMLElement;
  declare readonly prevYearButtonTarget: HTMLButtonElement;
  declare readonly nextYearButtonTarget: HTMLButtonElement;

  declare valueValue: string;
  declare minDateValue: string;
  declare maxDateValue: string;
  declare initialYearValue: number;
  declare nameValue: string;

  private currentYear!: number;
  private selectedWeek: string | null = null;
  private locale!: string;

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
    this.hiddenInputTarget.value = this.valueValue;

    // Update display (e.g., "KW 01, 2024")
    const [year, week] = weekStr.split('-W');
    this.displayTextTarget.textContent = `KW ${week}, ${year}`;

    // Dispatch change event (picker will close automatically on navigation)
    this.hiddenInputTarget.dispatchEvent(
      new Event('change', { bubbles: true }),
    );

    this.renderWeeks();
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
      monthRow.className = 'grid gap-px mb-1';
      monthRow.style.gridTemplateColumns = '2rem repeat(5, 1fr)';

      // Month label
      const monthLabel = document.createElement('div');
      monthLabel.className =
        'text-sm font-bold text-gray-600 dark:text-gray-400 flex items-center pr-3';
      const monthDate = DateTime.fromObject({
        year: this.currentYear,
        month: month,
      });
      monthLabel.textContent = monthDate.toFormat('MMM', {
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
          button.textContent = weekNum.toString().padStart(2, '0');
          button.className =
            'text-sm px-1 py-0.5 rounded text-center focus:outline-none focus:ring-1 focus:ring-indigo-500 tabular-nums';

          if (isDisabled) {
            button.className +=
              ' text-gray-300 dark:text-gray-600 cursor-not-allowed';
            button.disabled = true;
          } else {
            button.disabled = false;
            button.className += ' hover:bg-indigo-100 dark:hover:bg-indigo-900';
            button.addEventListener('click', (e) => {
              e.stopPropagation();
              this.selectWeek(e);
            });

            if (isSelected) {
              button.className +=
                ' bg-indigo-600 text-white hover:bg-indigo-700 dark:hover:bg-indigo-700';
            } else {
              button.className += ' text-gray-900 dark:text-white';
            }
          }

          monthRow.appendChild(button);
        } else {
          // Empty cell for alignment
          const emptyCell = document.createElement('div');
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

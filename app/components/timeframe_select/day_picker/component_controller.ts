import { Controller } from '@hotwired/stimulus';
import { DateTime } from 'luxon';

export default class extends Controller<HTMLElement> {
  static readonly targets = [
    'hiddenInput',
    'displayButton',
    'displayText',
    'modal',
    'monthYearDisplay',
    'weekdayHeader',
    'calendarGrid',
    'prevMonthButton',
    'nextMonthButton',
  ];

  static readonly values = {
    value: String,
    endingValue: String,
    minDate: String,
    maxDate: String,
    name: String,
    range: Boolean,
    baseClasses: String,
    selectedClasses: String,
    inRangeClasses: String,
    currentMonthClasses: String,
    otherMonthClasses: String,
    disabledClasses: String,
  };

  declare readonly hiddenInputTarget: HTMLInputElement;
  declare readonly displayButtonTarget: HTMLButtonElement;
  declare readonly displayTextTarget: HTMLElement;
  declare readonly modalTarget: HTMLElement;
  declare readonly monthYearDisplayTarget: HTMLElement;
  declare readonly weekdayHeaderTarget: HTMLElement;
  declare readonly calendarGridTarget: HTMLElement;
  declare readonly prevMonthButtonTarget: HTMLButtonElement;
  declare readonly nextMonthButtonTarget: HTMLButtonElement;

  declare valueValue: string;
  declare endingValueValue: string;
  declare minDateValue: string;
  declare maxDateValue: string;
  declare nameValue: string;
  declare rangeValue: boolean;
  declare baseClassesValue: string;
  declare selectedClassesValue: string;
  declare inRangeClassesValue: string;
  declare currentMonthClassesValue: string;
  declare otherMonthClassesValue: string;
  declare disabledClassesValue: string;

  // Delay in ms to ensure calendar rendering is complete before focusing
  private readonly FOCUS_DELAY_MS = 50;

  private currentMonth!: DateTime;
  private selectedStartDate: DateTime | null = null;
  private selectedEndDate: DateTime | null = null;
  private hoverDate: DateTime | null = null;
  private locale!: string;
  private focusedDate: DateTime | null = null;
  private focusTimeout?: ReturnType<typeof setTimeout>;
  private abortController?: AbortController;

  connect() {
    // Get browser locale from document or fallback to 'en'
    this.locale =
      document.documentElement.lang || navigator.language.split('-')[0] || 'en';

    // Initialize current month to the first selected date or today
    if (this.valueValue) {
      const parsed = DateTime.fromISO(this.valueValue);
      if (parsed.isValid) {
        this.currentMonth = parsed.startOf('month');
        this.selectedStartDate = parsed.startOf('day');
      } else {
        this.currentMonth = DateTime.now().startOf('month');
      }
    } else {
      this.currentMonth = DateTime.now().startOf('month');
    }

    // Initialize end date for range mode
    if (this.rangeValue && this.endingValueValue) {
      const parsed = DateTime.fromISO(this.endingValueValue);
      if (parsed.isValid) {
        this.selectedEndDate = parsed.startOf('day');
      }
    }

    this.renderWeekdayHeaders();
    this.renderCalendar();

    // Close dropdown when pressing Escape (use keyup to match modal's event)
    document.addEventListener('keyup', this.handleEscape, true);

    // Handle arrow key navigation
    document.addEventListener('keydown', this.handleKeyboardNavigation, true);

    // Close this picker when another picker opens
    document.addEventListener('picker:open', this.handleOtherPickerOpen);
  }

  disconnect() {
    if (this.focusTimeout) {
      clearTimeout(this.focusTimeout);
      this.focusTimeout = undefined;
    }

    // Abort all button event listeners
    this.abortController?.abort();

    document.removeEventListener('keyup', this.handleEscape, true);
    document.removeEventListener(
      'keydown',
      this.handleKeyboardNavigation,
      true,
    );
    document.removeEventListener('picker:open', this.handleOtherPickerOpen);
  }

  toggle(event: Event) {
    event.stopPropagation();
    event.preventDefault();

    if (this.modalTarget.classList.contains('hidden')) {
      this.open();
    } else {
      this.close();
    }
  }

  private open() {
    // Show modal
    this.modalTarget.classList.remove('hidden');

    // Initialize focused date when opening
    const minDate = this.getMinDate();
    const maxDate = this.getMaxDate();

    if (this.selectedStartDate) {
      this.focusedDate = this.selectedStartDate;
    } else {
      this.focusedDate = DateTime.now().startOf('day');
      // Ensure focused date is within bounds
      if (minDate && this.focusedDate < minDate) {
        this.focusedDate = minDate;
      }
      if (maxDate && this.focusedDate > maxDate) {
        this.focusedDate = maxDate;
      }
    }

    // Focus the current date after a short delay to ensure rendering is complete
    this.focusTimeout = setTimeout(() => {
      if (this.focusedDate) {
        this.focusDayButton(this.focusedDate);
      }
    }, this.FOCUS_DELAY_MS);

    // Notify other pickers to close
    document.dispatchEvent(
      new CustomEvent('picker:open', { detail: { picker: this.element } }),
    );
  }

  close() {
    this.modalTarget.classList.add('hidden');
    this.focusedDate = null;
  }

  private readonly handleEscape = (event: KeyboardEvent): void => {
    if (
      event.key === 'Escape' &&
      !this.modalTarget.classList.contains('hidden')
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

  private readonly handleKeyboardNavigation = (event: KeyboardEvent): void => {
    // Only handle keyboard navigation when modal is open
    if (this.modalTarget.classList.contains('hidden')) {
      return;
    }

    const minDate = this.getMinDate();
    const maxDate = this.getMaxDate();

    // Initialize focused date if not set
    if (!this.focusedDate) {
      // Start with selected date, or today if nothing selected
      if (this.selectedStartDate) {
        this.focusedDate = this.selectedStartDate;
      } else {
        this.focusedDate = DateTime.now().startOf('day');
        // Ensure focused date is within bounds
        if (minDate && this.focusedDate < minDate) {
          this.focusedDate = minDate;
        }
        if (maxDate && this.focusedDate > maxDate) {
          this.focusedDate = maxDate;
        }
      }
    }

    let newFocusedDate: DateTime | null = null;

    switch (event.key) {
      case 'ArrowLeft':
        event.preventDefault();
        newFocusedDate = this.focusedDate.minus({ days: 1 });
        break;
      case 'ArrowRight':
        event.preventDefault();
        newFocusedDate = this.focusedDate.plus({ days: 1 });
        break;
      case 'ArrowUp':
        event.preventDefault();
        newFocusedDate = this.focusedDate.minus({ weeks: 1 });
        break;
      case 'ArrowDown':
        event.preventDefault();
        newFocusedDate = this.focusedDate.plus({ weeks: 1 });
        break;
      case 'Enter':
        event.preventDefault();
        // Select the focused date
        if (this.focusedDate) {
          const isDisabled =
            (minDate && this.focusedDate < minDate) ||
            (maxDate && this.focusedDate > maxDate) ||
            false;
          if (!isDisabled) {
            if (this.rangeValue) {
              this.handleRangeSelection(this.focusedDate);
            } else {
              this.handleSingleSelection(this.focusedDate);
            }
            this.renderCalendar();
          }
        }
        return;
      default:
        return;
    }

    // Update focused date if navigation occurred
    if (newFocusedDate) {
      // Check if new date is within bounds
      const isDisabled =
        (minDate && newFocusedDate < minDate) ||
        (maxDate && newFocusedDate > maxDate) ||
        false;

      if (!isDisabled) {
        this.focusedDate = newFocusedDate;

        // Change month if focused date is in different month
        if (
          this.focusedDate.month !== this.currentMonth.month ||
          this.focusedDate.year !== this.currentMonth.year
        ) {
          this.currentMonth = this.focusedDate.startOf('month');
          this.renderCalendar();
        } else {
          // Just update classes without re-rendering if we're in the same month
          this.updateAllDayButtonClasses();
        }

        this.focusDayButton(this.focusedDate);
      }
    }
  };

  previousMonth() {
    this.currentMonth = this.currentMonth.minus({ months: 1 });
    this.renderCalendar();
  }

  nextMonth() {
    this.currentMonth = this.currentMonth.plus({ months: 1 });
    this.renderCalendar();
  }

  selectDay(event: Event) {
    const button = event.currentTarget as HTMLButtonElement;
    const dateStr = button.dataset.date;
    if (!dateStr) return;

    const date = DateTime.fromISO(dateStr);
    if (!date.isValid) return;

    if (this.rangeValue) {
      this.handleRangeSelection(date);
    } else {
      this.handleSingleSelection(date);
    }

    this.renderCalendar();
  }

  private handleSingleSelection(date: DateTime) {
    this.selectedStartDate = date.startOf('day');
    this.selectedEndDate = null;
    this.valueValue = date.toISODate()!;

    // Fire event for immediate navigation
    window.dispatchEvent(
      new CustomEvent('picker:selected', {
        detail: { value: this.valueValue, isRange: false },
      }),
    );
  }

  private handleRangeSelection(date: DateTime) {
    const normalizedDate = date.startOf('day');

    if (!this.selectedStartDate || this.selectedEndDate) {
      this.selectedStartDate = normalizedDate;
      this.selectedEndDate = null;
      this.displayTextTarget.textContent =
        this.selectedStartDate.toFormat('dd.MM.yyyy');
      return;
    }

    if (normalizedDate < this.selectedStartDate) {
      this.selectedEndDate = this.selectedStartDate;
      this.selectedStartDate = normalizedDate;
    } else {
      this.selectedEndDate = normalizedDate;
    }

    this.valueValue = this.selectedStartDate.toISODate()!;
    this.endingValueValue = this.selectedEndDate.toISODate()!;
    const rangeValue = `${this.valueValue}..${this.endingValueValue}`;

    // Fire event for immediate navigation
    window.dispatchEvent(
      new CustomEvent('picker:selected', {
        detail: { value: rangeValue, isRange: true },
      }),
    );
  }

  private renderWeekdayHeaders() {
    const weekdayFormatter = new Intl.DateTimeFormat(this.locale, {
      weekday: 'short',
    });
    const headerCells = this.weekdayHeaderTarget.children;

    for (let i = 1; i <= 7; i++) {
      const cell = headerCells[i - 1] as HTMLElement;
      if (cell) {
        const sampleDate = this.currentMonth.set({
          weekday: i as 1 | 2 | 3 | 4 | 5 | 6 | 7,
        });
        cell.textContent = weekdayFormatter.format(sampleDate.toJSDate());
      }
    }
  }

  private renderCalendar() {
    this.monthYearDisplayTarget.textContent = this.currentMonth.toFormat(
      'MMMM yyyy',
      {
        locale: this.locale,
      },
    );

    const minDate = this.getMinDate();
    const maxDate = this.getMaxDate();

    this.calendarGridTarget.innerHTML = '';
    this.renderDays(minDate, maxDate);
    this.updateNavigationButtons(minDate, maxDate);
  }

  private renderDays(minDate: DateTime | null, maxDate: DateTime | null) {
    // Abort old button listeners before re-rendering
    this.abortController?.abort();
    this.abortController = new AbortController();

    const startOfCalendar = this.currentMonth.startOf('month').startOf('week');
    const endOfCalendar = this.currentMonth.endOf('month').endOf('week');

    let currentDate = startOfCalendar;
    while (currentDate <= endOfCalendar) {
      const button = this.createDayButton(currentDate, minDate, maxDate);
      this.calendarGridTarget.appendChild(button);
      currentDate = currentDate.plus({ days: 1 });
    }

    // Add hover listener to grid for range preview (only mouseleave on grid, not individual buttons)
    if (this.rangeValue) {
      this.calendarGridTarget.addEventListener(
        'mouseleave',
        () => this.handleGridHoverEnd(),
        { signal: this.abortController.signal },
      );
    }
  }

  private createDayButton(
    date: DateTime,
    minDate: DateTime | null,
    maxDate: DateTime | null,
  ): HTMLButtonElement {
    const button = document.createElement('button');
    button.type = 'button';
    button.dataset.date = date.toISODate()!;
    button.textContent = date.day.toString();

    const isDisabled =
      (minDate && date < minDate) || (maxDate && date > maxDate) || false;

    if (isDisabled) {
      button.className = `${this.baseClassesValue} ${this.disabledClassesValue}`;
      button.disabled = true;
    } else {
      button.className = this.baseClassesValue + this.getDayClassName(date);
      button.addEventListener(
        'click',
        (e) => {
          e.stopPropagation();
          this.selectDay(e);
        },
        { signal: this.abortController?.signal },
      );

      // Add hover handlers for range mode preview (only mouseenter, mouseleave handled on grid)
      if (this.rangeValue) {
        button.addEventListener(
          'mouseenter',
          () => this.handleDayHover(date),
          { signal: this.abortController?.signal },
        );
      }
    }

    return button;
  }

  private getDayClassName(date: DateTime): string {
    if (this.isDateSelected(date)) {
      return ` ${this.selectedClassesValue}`;
    }
    if (this.isDateInRange(date) || this.isDateInHoverRange(date)) {
      return ` ${this.inRangeClassesValue}`;
    }
    if (date.month === this.currentMonth.month) {
      return ` ${this.currentMonthClassesValue}`;
    }
    return ` ${this.otherMonthClassesValue}`;
  }

  private updateNavigationButtons(
    minDate: DateTime | null,
    maxDate: DateTime | null,
  ) {
    if (minDate) {
      const prevMonth = this.currentMonth.minus({ months: 1 });
      this.prevMonthButtonTarget.disabled = prevMonth.endOf('month') < minDate;
    }
    if (maxDate) {
      const nextMonth = this.currentMonth.plus({ months: 1 });
      this.nextMonthButtonTarget.disabled =
        nextMonth.startOf('month') > maxDate;
    }
  }

  private isDateSelected(date: DateTime): boolean {
    const dateStr = date.toISODate();
    return (
      this.selectedStartDate?.toISODate() === dateStr ||
      this.selectedEndDate?.toISODate() === dateStr
    );
  }

  private isDateInRange(date: DateTime): boolean {
    if (!this.rangeValue || !this.selectedStartDate || !this.selectedEndDate)
      return false;

    const dateOnly = date.startOf('day');
    return dateOnly > this.selectedStartDate && dateOnly < this.selectedEndDate;
  }

  private isDateInHoverRange(date: DateTime): boolean {
    // Only show preview when start date is selected but end date is not yet selected
    if (!this.rangeValue || !this.selectedStartDate || this.selectedEndDate) {
      return false;
    }

    // Use either hover date (for mouse) or focused date (for keyboard)
    const previewDate = this.hoverDate || this.focusedDate;
    if (!previewDate) {
      return false;
    }

    const dateOnly = date.startOf('day');
    const timestamps = [
      this.selectedStartDate.toMillis(),
      previewDate.toMillis(),
    ];
    const start = DateTime.fromMillis(Math.min(...timestamps));
    const end = DateTime.fromMillis(Math.max(...timestamps));

    return dateOnly > start && dateOnly < end;
  }

  private handleDayHover(date: DateTime) {
    // Only handle hover if we're in range mode and have a start date but no end date
    if (!this.rangeValue || !this.selectedStartDate || this.selectedEndDate)
      return;

    const newHoverDate = date.startOf('day');
    // Only update if hover date actually changed to avoid unnecessary re-renders
    if (this.hoverDate?.toISODate() === newHoverDate.toISODate()) return;

    this.hoverDate = newHoverDate;
    this.updateAllDayButtonClasses();
  }

  private handleGridHoverEnd() {
    if (!this.hoverDate) return;

    this.hoverDate = null;
    // Only update if we don't have a focused date (keyboard navigation)
    // If we have a focused date, keep showing the keyboard preview
    if (!this.focusedDate || this.selectedEndDate) {
      this.updateAllDayButtonClasses();
    }
  }

  private updateAllDayButtonClasses() {
    // Update classes for all day buttons in the grid
    const buttons =
      this.calendarGridTarget.querySelectorAll('button[data-date]');
    const minDate = this.getMinDate();
    const maxDate = this.getMaxDate();

    for (const button of buttons) {
      const dateStr = (button as HTMLButtonElement).dataset.date;
      if (!dateStr) continue;

      const date = DateTime.fromISO(dateStr);
      if (!date.isValid) continue;

      const isDisabled =
        (minDate && date < minDate) || (maxDate && date > maxDate) || false;

      // Reset to base classes and re-apply state classes
      if (isDisabled) {
        button.className = `${this.baseClassesValue} ${this.disabledClassesValue}`;
      } else {
        button.className = this.baseClassesValue + this.getDayClassName(date);
      }
    }
  }

  private focusDayButton(date: DateTime) {
    const dateStr = date.toISODate();
    const button = this.calendarGridTarget.querySelector(
      `button[data-date="${dateStr}"]`,
    ) as HTMLButtonElement;

    if (button && !button.disabled) {
      button.focus();
    }
  }

  private getMinDate(): DateTime | null {
    return this.minDateValue
      ? DateTime.fromISO(this.minDateValue).startOf('day')
      : null;
  }

  private getMaxDate(): DateTime | null {
    return this.maxDateValue
      ? DateTime.fromISO(this.maxDateValue).startOf('day')
      : null;
  }
}

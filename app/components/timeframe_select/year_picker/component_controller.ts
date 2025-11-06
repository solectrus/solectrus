import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLElement> {
  static readonly targets = [
    'hiddenInput',
    'displayButton',
    'displayText',
    'modal',
    'yearCell',
  ];

  static readonly values = {
    value: String,
    minYear: Number,
    maxYear: Number,
    name: String,
  };

  declare readonly hiddenInputTarget: HTMLInputElement;
  declare readonly displayButtonTarget: HTMLButtonElement;
  declare readonly displayTextTarget: HTMLElement;
  declare readonly modalTarget: HTMLElement;
  declare readonly yearCellTargets: HTMLButtonElement[];

  declare valueValue: string;
  declare minYearValue: number;
  declare maxYearValue: number;
  declare nameValue: string;

  private selectedYear: number | null = null;

  connect() {
    // Initialize selected year
    if (this.valueValue) {
      const year = parseInt(this.valueValue, 10);
      if (!isNaN(year)) {
        this.selectedYear = year;
      }
    }

    this.renderYears();

    // Close dropdown when pressing Escape
    document.addEventListener('keyup', this.handleEscape, true);

    // Close this picker when another picker opens
    document.addEventListener('picker:open', this.handleOtherPickerOpen);
  }

  disconnect() {
    document.removeEventListener('keyup', this.handleEscape, true);
    document.removeEventListener('picker:open', this.handleOtherPickerOpen);
  }

  toggle(event: Event) {
    event.stopPropagation();
    event.preventDefault();
    const wasHidden = this.modalTarget.classList.contains('hidden');

    if (wasHidden) {
      this.open();
    } else {
      this.close();
    }
  }

  private open() {
    // Show modal
    this.modalTarget.classList.remove('hidden');

    // Notify other pickers to close
    document.dispatchEvent(
      new CustomEvent('picker:open', { detail: { picker: this.element } }),
    );
  }

  close() {
    this.modalTarget.classList.add('hidden');
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

  selectYear(event: Event) {
    const button = event.currentTarget as HTMLButtonElement;
    const yearStr = button.dataset.year;
    if (!yearStr) return;

    const year = parseInt(yearStr, 10);
    if (isNaN(year)) return;

    this.selectedYear = year;
    this.valueValue = year.toString();

    // Fire event for immediate navigation
    window.dispatchEvent(
      new CustomEvent('picker:selected', {
        detail: { value: this.valueValue, isRange: false },
      }),
    );
  }

  private renderYears() {
    for (const cell of this.yearCellTargets) {
      const yearStr = cell.dataset.year;
      if (!yearStr) continue;

      const year = parseInt(yearStr, 10);
      const isSelected = this.selectedYear === year;

      // Reset classes
      cell.className =
        'text-base py-4 rounded-lg text-center focus:outline-none focus:ring-2 focus:ring-indigo-500';

      // Apply styling based on state
      cell.className += ' hover:bg-indigo-100 dark:hover:bg-indigo-900';

      if (isSelected) {
        cell.className +=
          ' bg-indigo-600 text-white hover:bg-indigo-700 dark:hover:bg-indigo-700';
      } else {
        cell.className += ' text-gray-900 dark:text-white';
      }
    }
  }
}

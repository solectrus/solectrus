import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { isReducedMotion } from '@/utils/device';
import { EASE_GLIDE } from '@/utils/motion';

// The sheet glides to its new height when a picker opens or closes
const RESIZE_DURATION = 350;

// Connects to data-controller="timeframe--select--component"
export default class extends Controller<HTMLElement> {
  static readonly values = {
    // The address of the page with ":timeframe" in place of the timeframe
    urlTemplate: String,
    id: String,
  };

  declare readonly urlTemplateValue: string;
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

  // The height of the sheet before the last change, and the glide from it
  #height?: number;
  #glide?: Animation;
  #sizes?: ResizeObserver;
  #toggles?: MutationObserver;

  connect(): void {
    this.observeHeight();
    this.autoOpenPicker();
  }

  disconnect(): void {
    this.#sizes?.disconnect();
    this.#toggles?.disconnect();
    this.#glide?.cancel();
  }

  handlePickerSelected(event: CustomEvent): void {
    const { value } = event.detail;

    if (value) this.visit(value);
  }

  // The field of a picker selects the period it shows. The button lies in the
  // summary of the picker, which must not open.
  choose(event: Event & { params: { value: string | number } }): void {
    event.preventDefault();
    this.visit(String(event.params.value));
  }

  private visit(timeframe: string): void {
    Turbo.visit(this.urlTemplateValue.replace(':timeframe', timeframe));
  }

  // An open picker gives the sheet another height (see component.css). The
  // mutation observer answers before the next paint, so the sheet glides
  // from the old height, which the resize observer keeps. The picker that
  // opens at connect has no old height yet and does not glide.
  private observeHeight(): void {
    const panel = this.element.closest<HTMLElement>('.bottom-sheet-panel');
    if (!panel) return;

    this.#sizes = new ResizeObserver(() => {
      if (!this.gliding) this.#height = panel.offsetHeight;
    });
    this.#sizes.observe(panel);

    this.#toggles = new MutationObserver(() => this.glide(panel));
    this.#toggles.observe(this.element, {
      attributeFilter: ['open'],
      subtree: true,
    });
  }

  private get gliding(): boolean {
    return this.#glide?.playState === 'running';
  }

  // A glide that runs starts the next one from where it is
  private glide(panel: HTMLElement): void {
    const from = this.gliding ? panel.offsetHeight : this.#height;
    this.#glide?.cancel();

    const to = panel.offsetHeight;
    this.#height = to;
    if (from === undefined || from === to || isReducedMotion()) return;

    this.#glide = panel.animate(
      { height: [`${from}px`, `${to}px`] },
      { duration: RESIZE_DURATION, easing: EASE_GLIDE },
    );
  }

  // The picker of the period opens at once. Its way back leads to the fields.
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

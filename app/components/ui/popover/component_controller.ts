import { Controller } from '@hotwired/stimulus';
import { enter, leave } from '@/utils/transition';

// Opens and closes the panel of Ui::Popover::Component. While the panel is
// open, a click beside it and Escape close it. The listeners on the document
// exist only for that time, so a page with many closed popovers pays nothing.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['button', 'panel'];

  declare readonly buttonTarget: HTMLElement;
  declare readonly panelTarget: HTMLElement;

  #open = false;

  disconnect() {
    this.#unlisten();
  }

  toggle() {
    if (this.#open) this.close();
    else this.open();
  }

  open() {
    if (this.#open) return;

    this.#open = true;
    this.buttonTarget.ariaExpanded = 'true';
    document.addEventListener('click', this.#clickBeside);
    document.addEventListener('keydown', this.#keydown);
    void enter(this.panelTarget);
  }

  close() {
    if (!this.#open) return;

    this.#open = false;
    this.buttonTarget.ariaExpanded = 'false';
    this.#unlisten();
    void leave(this.panelTarget);
  }

  // Stimulus Action: the pick of an entry closes a menu
  pick(event: Event) {
    if ((event.target as Element | null)?.closest('a, button')) this.close();
  }

  // Stimulus Action: a native select that stands in for the menu, like on a
  // phone. The entry it picked is one of the links of the panel. Clicking the
  // link rather than following its href keeps whatever the link itself
  // decides about the navigation.
  choose(event: Event) {
    const select = event.target;
    if (!(select instanceof HTMLSelectElement) || !select.value) return;

    this.panelTarget
      .querySelector<HTMLAnchorElement>(`a[href="${CSS.escape(select.value)}"]`)
      ?.click();
  }

  #unlisten() {
    document.removeEventListener('click', this.#clickBeside);
    document.removeEventListener('keydown', this.#keydown);
  }

  // The click that opens the panel reaches the document too, so a click
  // inside the popover does not count
  readonly #clickBeside = (event: Event) => {
    if (event.target instanceof Node && this.element.contains(event.target))
      return;

    this.close();
  };

  // Escape closes the panel alone, not a sheet around it
  readonly #keydown = (event: KeyboardEvent) => {
    if (event.key !== 'Escape') return;

    event.preventDefault();
    this.close();
    this.buttonTarget.focus();
  };
}

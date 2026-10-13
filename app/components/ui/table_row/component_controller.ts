import { Controller } from '@hotwired/stimulus';

// The breakpoint lg of Tailwind, from which the row opens its entry in the
// modal
const desktop = window.matchMedia('(min-width: 64rem)');

// Passes a click on a table row on to the link of the row, see
// Ui::TableRow::Component. A click on another control of the row keeps its
// own meaning, and so does a click that ends a text selection.
//
// The link opens a page of its own on a phone. From lg up, the controller
// points it to the modal, also after the screen turns.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['link'];

  declare readonly linkTarget: HTMLAnchorElement;

  connect(): void {
    this.route();
    desktop.addEventListener('change', this.route);
  }

  disconnect(): void {
    desktop.removeEventListener('change', this.route);
  }

  open(event: MouseEvent): void {
    const target = event.target as Element;
    if (target.closest('a, button, input, select, textarea, label')) return;
    if (window.getSelection()?.toString()) return;

    // With a modifier, the entry opens in a new tab or window, as a click on
    // the link itself does. A forwarded click would open the modal instead.
    if (event.metaKey || event.ctrlKey || event.shiftKey) {
      window.open(this.linkTarget.href, '_blank', 'noopener');
      return;
    }

    this.linkTarget.click();
  }

  private readonly route = (): void => {
    if (desktop.matches) this.linkTarget.dataset.turboFrame = 'modal';
    else delete this.linkTarget.dataset.turboFrame;
  };
}

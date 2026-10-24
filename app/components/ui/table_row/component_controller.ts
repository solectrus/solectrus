import { Controller } from '@hotwired/stimulus';

// The breakpoint lg of Tailwind, from which the row opens its entry in the
// modal
const desktop = window.matchMedia('(min-width: 64rem)');

// The parameter that asks for the form in a sheet (see FormPageHelper)
const FORM_SHEET = 'form_sheet';

// Passes a click on a table row on to the link of the row, see
// Ui::TableRow::Component. A click on another control of the row keeps its
// own meaning, and so does a click that ends a text selection.
//
// The link opens a page of its own on a phone, or with `formSheet` the form
// of the entry in a sheet. From lg up, the controller points it to the
// modal, also after the screen turns.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['link'];
  static readonly values = { formSheet: Boolean };

  declare readonly linkTarget: HTMLAnchorElement;
  declare readonly formSheetValue: boolean;

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
    const link = this.linkTarget;
    const sheet = !desktop.matches && this.formSheetValue;
    if (this.formSheetValue) {
      const url = new URL(link.href);
      if (sheet) url.searchParams.set(FORM_SHEET, '1');
      else url.searchParams.delete(FORM_SHEET);
      link.href = url.pathname + url.search + url.hash;
    }

    if (desktop.matches || sheet) link.dataset.turboFrame = 'modal';
    else delete link.dataset.turboFrame;
  };
}

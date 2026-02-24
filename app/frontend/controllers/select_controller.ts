import { Controller } from '@hotwired/stimulus';
export default class extends Controller<HTMLSelectElement> {
  static readonly targets = ['select', 'temp'];

  declare readonly selectTarget: HTMLSelectElement;
  declare readonly tempTarget: HTMLSelectElement;

  connect() {
    this.autoWidth();
  }

  onChange() {
    const url = this.selectTarget.value;
    if (!url) return;

    this.findMenuItemLink(url)?.click();
  }

  autoWidth() {
    this.selectTarget.style.width = `${this.widthOfSelectedOption}px`;
  }

  // Find the desktop menu link matching the selected option URL so we can
  // trigger the exact same Stimulus action chain on mobile.
  private findMenuItemLink(url: string): HTMLAnchorElement | null {
    const container = this.element.parentElement;
    if (!container) return null;

    const selector = `a[href="${CSS.escape(url)}"]`;
    return container.querySelector<HTMLAnchorElement>(selector);
  }

  // Hack to get the width of the selected option
  get widthOfSelectedOption() {
    // Get the text of the selected option
    const text =
      this.selectTarget.options[this.selectTarget.selectedIndex].text;

    // Use a temporary select which has just ONE option - the selected one
    this.tempTarget.innerHTML = `<option selected>${text}</option>`;

    // Return the width of the temporary select
    return this.tempTarget.clientWidth;
  }
}

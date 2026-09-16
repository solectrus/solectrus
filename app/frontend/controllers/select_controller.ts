import { Controller } from '@hotwired/stimulus';
export default class SelectController extends Controller<HTMLSelectElement> {
  static readonly targets = ['select', 'temp'];

  declare readonly selectTarget: HTMLSelectElement;
  declare readonly tempTarget: HTMLSelectElement;

  // `field-sizing: content` shrink-wraps the select in CSS alone, so the
  // measuring hack below is dead weight wherever the browser has it.
  private static readonly hasFieldSizing =
    typeof CSS !== 'undefined' && CSS.supports('field-sizing', 'content');

  private widthFrame?: number;

  connect() {
    this.autoWidth();
  }

  disconnect() {
    if (this.widthFrame !== undefined) cancelAnimationFrame(this.widthFrame);
  }

  onChange() {
    const url = this.selectTarget.value;
    if (!url) return;

    this.findMenuItemLink(url)?.click();
  }

  // Reading `clientWidth` forces a synchronous layout. Called straight from
  // `connect()` that lands before the first paint, so it drags the layout of
  // the whole page in front of it - 34ms of it on a throttled phone, all of it
  // added to LCP. A frame later the paint is out, and the same measurement is
  // free. The select is invisible until then only in the sense that it has yet
  // to be shrunk, which is one frame of a slightly wider control, not a jump
  // the eye catches.
  autoWidth() {
    if (SelectController.hasFieldSizing) return;

    this.widthFrame = requestAnimationFrame(() => {
      this.widthFrame = undefined;
      if (!this.element.isConnected) return;

      this.selectTarget.style.width = `${this.widthOfSelectedOption}px`;
    });
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

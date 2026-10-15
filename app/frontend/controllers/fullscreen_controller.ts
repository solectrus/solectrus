import { Controller } from '@hotwired/stimulus';

// Fullscreen is a mode of the document, which Turbo keeps from page to page.
//
// The menu of the desktop carries two items for it, one to enter it and one
// to leave it. CSS keeps both away until this controller marks <html> with
// `data-fullscreen-api`, and `:fullscreen` then picks the item that fits the
// current state. Both markers sit on <html>, outside the body that Turbo
// replaces or morphs, so no page change can bring a stale item back.
//
// The page More of a phone has a switch instead. It follows the mode, which
// the browser can also leave on its own, like with the Escape key.
export default class extends Controller {
  static readonly targets = ['switch'];
  declare readonly switchTargets: HTMLInputElement[];

  connect() {
    document.documentElement.toggleAttribute(
      'data-fullscreen-api',
      this.supported,
    );
    document.addEventListener('fullscreenchange', this.sync);
    // A morph sets the switch back to the state the server rendered
    document.addEventListener('turbo:morph', this.sync);
  }

  disconnect() {
    document.removeEventListener('fullscreenchange', this.sync);
    document.removeEventListener('turbo:morph', this.sync);
  }

  switchTargetConnected(element: HTMLInputElement) {
    element.checked = !!document.fullscreenElement;
  }

  on() {
    if (!this.supported || document.fullscreenElement) return;

    document.documentElement.requestFullscreen().catch(this.sync);
  }

  off() {
    if (document.fullscreenElement) document.exitFullscreen();
  }

  toggle(event: Event) {
    if ((event.target as HTMLInputElement).checked) this.on();
    else this.off();
  }

  private readonly sync = () => {
    for (const element of this.switchTargets) {
      element.checked = !!document.fullscreenElement;
    }
  };

  // Safari on the iPhone has no Fullscreen API at all: the method is missing.
  private get supported() {
    return typeof document.documentElement.requestFullscreen === 'function';
  }
}

import { Controller } from '@hotwired/stimulus';

// The menu carries two items for fullscreen, one to enter it and one to leave
// it. CSS keeps both away until this controller marks <html> with
// `data-fullscreen-api`, and `:fullscreen` then picks the item that fits the
// current state. Both markers sit on <html>, outside the body that Turbo
// replaces or morphs, so no page change can bring a stale item back.
export default class extends Controller {
  connect() {
    document.documentElement.toggleAttribute(
      'data-fullscreen-api',
      this.supported,
    );
  }

  on() {
    if (!this.supported || document.fullscreenElement) return;

    document.documentElement.requestFullscreen();
  }

  off() {
    if (document.fullscreenElement) document.exitFullscreen();
  }

  // Safari on the iPhone has no Fullscreen API at all: the method is missing.
  private get supported() {
    return typeof document.documentElement.requestFullscreen === 'function';
  }
}

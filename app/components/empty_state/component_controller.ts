import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

// Detects when sensor data becomes available by polling via a hidden
// Turbo Frame (<turbo-frame id="sensor-check">).
//
// How it works:
// 1. Every 3 s the hidden frame reloads the current page.
// 2. Turbo extracts the matching <turbo-frame id="sensor-check">
//    from the response and swaps it in — invisibly, because the
//    frame is hidden. The visible animation is never touched.
// 3. Once data arrives the server renders the dashboard instead of
//    the empty state, so the frame no longer exists in the response.
//    Turbo fires "turbo:frame-missing".
// 4. We catch that event and do a single Turbo.visit() to replace
//    the whole page with the dashboard.
export default class extends Controller {
  static readonly targets = ['frame'];
  declare readonly frameTarget: Turbo.FrameElement;

  private timer?: ReturnType<typeof setInterval>;

  connect() {
    this.frameTarget.addEventListener('turbo:frame-missing', this.onMissing);

    this.timer = setInterval(() => {
      // First tick: set src to start frame navigation.
      // Subsequent ticks: reload from the already-known src.
      if (this.frameTarget.src) this.frameTarget.reload();
      else this.frameTarget.src = window.location.href;
    }, 3000);
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer);
    this.frameTarget.removeEventListener('turbo:frame-missing', this.onMissing);
  }

  // The frame is missing from the server response → sensor data has
  // arrived and the server now renders the dashboard. Prevent the
  // default error handling and navigate to the dashboard.
  private onMissing = (event: Event) => {
    event.preventDefault();
    if (this.timer) clearInterval(this.timer);
    Turbo.visit(window.location.href, { action: 'replace' });
  };
}

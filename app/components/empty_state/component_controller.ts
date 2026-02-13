import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller {
  private timer?: ReturnType<typeof setInterval>;

  connect() {
    this.timer = setInterval(() => {
      Turbo.visit(window.location.href, { action: 'replace' });
    }, 2500);
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer);
  }
}

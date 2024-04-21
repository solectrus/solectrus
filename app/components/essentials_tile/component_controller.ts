import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller {
  intervalId: number | NodeJS.Timeout = 0;

  static values = {
    interval: { type: Number, default: 5 },
  };

  declare intervalValue: number;

  connect() {
    this.startLoop();
    this.addListeners();
  }

  disconnect(): void {
    this.removeListeners();
    this.stopLoop();
  }

  addListeners(): void {
    document.addEventListener(
      'visibilitychange',
      this.handleVisibilityChange.bind(this),
    );
  }

  removeListeners(): void {
    document.removeEventListener(
      'visibilitychange',
      this.handleVisibilityChange.bind(this),
    );
  }

  startLoop() {
    this.intervalId = setTimeout(() => {
      this.reload();
    }, this.intervalValue * 1000);
  }

  stopLoop() {
    clearTimeout(this.intervalId);
  }

  handleVisibilityChange(): void {
    if (document.hidden) this.stopLoop();
    else {
      this.reload();
      this.startLoop();
    }
  }

  reload() {
    this.frame?.reload();
  }

  get frame(): Turbo.FrameElement | null {
    return this.element.closest('turbo-frame');
  }
}

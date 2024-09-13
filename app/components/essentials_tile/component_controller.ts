import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller {
  intervalId: number | NodeJS.Timeout = 0;

  static readonly values = {
    interval: { type: Number, default: 5 },
  };

  declare intervalValue: number;

  private boundHandleVisibilityChange?: () => void;

  connect() {
    this.startLoop();
    this.addListeners();
  }

  disconnect(): void {
    this.removeListeners();
    this.stopLoop();
  }

  addListeners(): void {
    this.boundHandleVisibilityChange = this.handleVisibilityChange.bind(this);
    document.addEventListener(
      'visibilitychange',
      this.boundHandleVisibilityChange,
    );
  }

  removeListeners(): void {
    if (this.boundHandleVisibilityChange)
      document.removeEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
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

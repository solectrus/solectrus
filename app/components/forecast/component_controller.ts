import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { IntervalTimer } from '@/utils/intervalTimer';

export default class extends Controller {
  static readonly values = {
    // Refresh interval in seconds
    interval: Number,
  };
  declare readonly intervalValue: number;

  private timer?: IntervalTimer;
  private abortController?: AbortController;

  connect() {
    if (!this.intervalValue) return;

    this.abortController = new AbortController();

    this.timer = new IntervalTimer(
      () => this.reloadCharts().catch(console.error),
      this.intervalValue * 1000,
    );
    this.timer.start();

    document.addEventListener('visibilitychange', this.handleVisibilityChange, {
      signal: this.abortController.signal,
    });
  }

  disconnect() {
    this.abortController?.abort();
    this.abortController = undefined;

    this.timer?.stop();
    this.timer = undefined;
  }

  private handleVisibilityChange = (): void => {
    if (document.hidden) {
      this.timer?.stop();
    } else {
      this.reloadCharts()
        .then(() => this.timer?.start())
        .catch(console.error);
    }
  };

  private async reloadCharts() {
    const frames = this.element.querySelectorAll<Turbo.FrameElement>(
      'turbo-frame#inverter-power-forecast-chart, turbo-frame#outdoor-temp-forecast-chart',
    );

    await Promise.all(Array.from(frames).map((frame) => frame.reload()));
  }
}

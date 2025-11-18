import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { IntervalTimer } from '@/utils/intervalTimer';

const REFRESH_INTERVAL = 5 * 60 * 1000; // 5 minutes

export default class extends Controller {
  private timer?: IntervalTimer;
  private abortController?: AbortController;

  connect() {
    this.abortController = new AbortController();

    this.timer = new IntervalTimer(
      () => this.reloadCharts().catch(console.error),
      REFRESH_INTERVAL,
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

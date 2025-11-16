import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { IntervalTimer } from '@/utils/intervalTimer';

export default class extends Controller {
  static readonly values = {
    // Refresh interval in seconds (default: 5 minutes)
    interval: { type: Number, default: 300 },
  };
  declare readonly intervalValue: number;

  private timer?: IntervalTimer;
  private boundHandleVisibilityChange?: () => void;
  private shouldStopRequests = false;

  connect() {
    if (this.intervalValue) {
      this.createTimer();

      this.boundHandleVisibilityChange = this.handleVisibilityChange.bind(this);
      document.addEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
      );
    }

    this.startLoop();
  }

  disconnect() {
    this.removeTimer();

    if (this.boundHandleVisibilityChange)
      document.removeEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
      );
  }

  reload() {
    this.reloadCharts().catch((error) => {
      console.error(error);
      // Ignore error
    });
  }

  createTimer() {
    // Create a timer to reload both chart frames
    this.timer = new IntervalTimer(() => {
      // Avoid any request if stopped in the meantime
      if (this.shouldStopRequests) return;

      this.reload();
    }, this.intervalValue * 1000);
  }

  removeTimer() {
    this.timer?.stop();
    this.timer = undefined;
  }

  startLoop() {
    if (!this.timer) return;

    // Avoid starting multiple loops
    if (this.isInLoop) return;

    // Reset the flag to stop requests
    this.shouldStopRequests = false;

    this.timer.start();
  }

  stopLoop() {
    this.shouldStopRequests = true;
    this.timer?.stop();
  }

  get isInLoop() {
    return this.timer?.isActive();
  }

  handleVisibilityChange(): void {
    if (document.hidden) this.stopLoop();
    else
      this.reloadCharts()
        .then(() => this.startLoop())
        .catch((error) => console.error(error));
  }

  async reloadCharts() {
    try {
      const powerChartFrame = this.element.querySelector<Turbo.FrameElement>(
        'turbo-frame#inverter-power-forecast-chart',
      );
      const temperatureChartFrame =
        this.element.querySelector<Turbo.FrameElement>(
          'turbo-frame#outdoor-temp-forecast-chart',
        );

      const reloadPromises = [];

      if (powerChartFrame) {
        reloadPromises.push(powerChartFrame.reload());
      }

      if (temperatureChartFrame) {
        reloadPromises.push(temperatureChartFrame.reload());
      }

      await Promise.all(reloadPromises);
    } catch (error) {
      console.error(error);
    }
  }
}

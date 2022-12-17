import { Controller } from '@hotwired/stimulus';
import { FrameElement } from '@hotwired/turbo';
import { Chart } from 'chart.js';

export default class extends Controller<FrameElement> {
  static targets = ['current'];

  static values = {
    src: String,
  };

  private interval: ReturnType<typeof setInterval> | undefined;
  private lastTime: Date | undefined;

  declare srcValue: string;
  declare readonly hasSrcValue: boolean;

  declare readonly hasCurrentTarget: boolean;
  declare readonly currentTarget: HTMLElement;
  declare readonly currentTargets: HTMLElement[];

  connect() {
    this.interval = setInterval(async () => {
      // Reload frame
      this.element.src = null;
      this.element.src = this.srcValue;

      try {
        await this.element.loaded;
      } catch (error) {
        console.log(error);
        // Ignore error
      }

      this.updateChart();
    }, 5000);
  }

  disconnect() {
    clearInterval(this.interval);
  }

  updateChart() {
    if (!this.hasCurrentTarget) return;
    if (!this.currentTime || !this.currentValue) return;

    const chart = this.chartNow;
    if (!chart) return;

    if (this.chartIsStale) {
      // Updating an old chart is not possible, so reload the page
      location.reload();
      return;
    }

    // Remember the current time for the next check
    this.lastTime = this.currentTime;

    // Remove oldest point (label + value in all datasets)
    chart.data.labels?.shift();
    chart.data.datasets.forEach((dataset) => {
      dataset.data.shift();
    });

    // Add new point
    // First, add the current time as a label
    chart.data.labels?.push(this.currentTime.toISOString());

    // Second, add the current value to the appropriate dataset
    // There may be two datasets: One for positive, one for negative values.
    // Write currentValue to the appropriate dataset
    if (this.currentValue > 0) {
      this.positiveDataset(chart)?.data.push(this.currentValue);
      this.negativeDataset(chart)?.data.push(0);
    } else {
      this.negativeDataset(chart)?.data.push(this.currentValue);
      this.positiveDataset(chart)?.data.push(0);
    }

    // Redraw the chart
    chart.update();
  }

  get chartNow() {
    return Object.values(Chart.instances).find(
      (c) => c.canvas.id == 'chart-now',
    );
  }

  get currentValue(): number | undefined {
    if (this.currentTarget.dataset.value)
      return parseFloat(this.currentTarget.dataset.value);
  }

  get currentTime(): Date | undefined {
    if (this.currentTarget.dataset.time)
      return new Date(this.currentTarget.dataset.time);
  }

  get chartIsStale(): boolean {
    if (this.lastTime && this.currentTime)
      // The chart is stale if the last time is more than 10 seconds ago
      return this.currentTime > this.addSeconds(this.lastTime, 10);

    return false;
  }

  addSeconds(date: Date, seconds: number): Date {
    return new Date(date.getTime() + seconds * 1000);
  }

  // The positive dataset is where at least one positive value exist
  positiveDataset(chart: Chart) {
    return chart.data.datasets.find((dataset) =>
      dataset.data.some((v) => v && v > 0),
    );
  }

  // The negative dataset is where at least one negative value exist
  negativeDataset(chart: Chart) {
    return chart.data.datasets.find((dataset) =>
      dataset.data.some((v) => v && v < 0),
    );
  }
}

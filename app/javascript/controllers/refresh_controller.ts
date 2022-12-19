import { Controller } from '@hotwired/stimulus';
import { FrameElement } from '@hotwired/turbo';
import { Chart } from 'chart.js';

export default class extends Controller {
  static targets = ['current', 'stats', 'chart'];

  declare readonly hasCurrentTarget: boolean;
  declare readonly currentTarget: HTMLElement;
  declare readonly currentTargets: HTMLElement[];

  declare readonly hasChartTarget: boolean;
  declare readonly chartTarget: HTMLCanvasElement;
  declare readonly chartTargets: HTMLCanvasElement[];

  declare readonly hasStatsTarget: boolean;
  declare readonly statsTarget: FrameElement;
  declare readonly statsTargets: FrameElement[];

  static values = {
    field: String,
  };
  declare readonly fieldValue: string;

  private interval: ReturnType<typeof setInterval> | undefined;

  connect() {
    window.addEventListener('blur', this.handleBlur.bind(this));
    window.addEventListener('focus', this.handleFocus.bind(this));
    document.addEventListener(
      'visibilitychange',
      this.handleVisibilityChange.bind(this),
    );

    this.startLoop();
  }

  disconnect() {
    this.stopLoop();

    document.removeEventListener(
      'visibilitychange',
      this.handleVisibilityChange.bind(this),
    );
    window.removeEventListener('focus', this.handleFocus.bind(this));
    window.removeEventListener('blur', this.handleBlur.bind(this));
  }

  startLoop() {
    this.stopLoop();

    this.interval = setInterval(async () => {
      try {
        await this.reloadFrame({ chart: false });
      } catch (error) {
        console.log(error);
        // Ignore error
      }

      this.updateChart();
    }, 5000);
  }

  stopLoop() {
    if (this.isInLoop) clearInterval(this.interval);
    this.interval = undefined;
  }

  get isInLoop() {
    return !!this.interval;
  }

  handleBlur() {
    this.stopLoop();
  }

  handleFocus() {
    this.reloadFrame({ chart: true });
    this.startLoop();
  }

  handleVisibilityChange() {
    if (document.hidden) this.stopLoop();
    else {
      this.reloadFrame({ chart: true });
      this.startLoop();
    }
  }

  updateChart() {
    if (!this.hasCurrentTarget) return;
    if (!this.currentValue) return;
    if (!this.chart) return;

    // Remove oldest point (label + value in all datasets)
    this.chart.data.labels?.shift();
    this.chart.data.datasets.forEach((dataset) => {
      dataset.data.shift();
    });

    // Add new point
    // First, add the current time as a label
    this.chart.data.labels?.push(new Date().toISOString());

    // Second, add the current value to the appropriate dataset
    // There may be two datasets: One for positive, one for negative values.
    // Write currentValue to the appropriate dataset
    if (this.currentValue > 0) {
      this.positiveDataset?.data.push(this.currentValue);
      this.negativeDataset?.data.push(0);
    } else {
      this.negativeDataset?.data.push(this.currentValue);
      this.positiveDataset?.data.push(0);
    }

    // Redraw the chart
    this.chart.update();
  }

  async reloadFrame(options: { chart: boolean }) {
    if (!this.statsTarget.src) {
      return;
    }

    const url = new URL(this.statsTarget.src, location.origin);
    url.searchParams.set('chart', options.chart.toString());

    this.statsTarget.src = null;
    this.statsTarget.src = url.toString();

    await this.statsTarget.loaded;
  }

  get chart() {
    if (this.hasChartTarget) return Chart.getChart(this.chartTarget);
  }

  get currentValue(): number | undefined {
    if (this.currentElement?.dataset.value)
      return parseFloat(this.currentElement.dataset.value);
  }

  get currentElement(): HTMLElement | undefined {
    // Select the current element from the currentTargets (by comparing field)
    const targets = this.currentTargets.filter((t) =>
      t.dataset.field?.startsWith(this.fieldValue),
    );

    if (targets.length)
      // Return the first element with a non-zero value, or the first element
      return (
        targets.find((t) => parseFloat(t.dataset.value ?? '') !== 0) ||
        targets[0]
      );
  }

  // The positive dataset is where at least one positive value exist
  get positiveDataset() {
    return this.chart?.data.datasets.find((dataset) =>
      dataset.data.some((v) => v && v > 0),
    );
  }

  // The negative dataset is where at least one negative value exist
  get negativeDataset() {
    return this.chart?.data.datasets.find((dataset) =>
      dataset.data.some((v) => v && v < 0),
    );
  }
}

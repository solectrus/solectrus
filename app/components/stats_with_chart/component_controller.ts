import { Controller, ActionEvent } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { Chart } from 'chart.js';
import { application } from '@/utils/setupStimulus';
import TippyController from '@/controllers/tippy_controller';

export default class extends Controller {
  static readonly targets = ['current', 'stats', 'chart', 'canvas'];

  declare readonly hasCurrentTarget: boolean;
  declare readonly currentTargets: HTMLElement[];

  declare readonly hasChartTarget: boolean;
  declare readonly chartTarget: Turbo.FrameElement;

  declare readonly hasStatsTarget: boolean;
  declare readonly statsTarget: Turbo.FrameElement;

  declare readonly hasCanvasTarget: boolean;
  declare readonly canvasTarget: HTMLCanvasElement;

  static readonly values = {
    // Field to display in the chart
    sensor: String,

    // Refresh interval in seconds
    interval: { type: Number, default: 5 },

    // Should the chart be reloaded when the page is reloaded?
    // If false, the chart will be updated by adding a new point
    reloadChart: { type: Boolean, default: false },

    // Path to the next page
    nextPath: String,

    // After this time (ISO 8601 decoded), nextPath will be loaded instead of the current page
    boundary: String,
  };
  declare readonly sensorValue: string;
  declare readonly intervalValue: number;
  declare readonly reloadChartValue: boolean;
  declare readonly nextPathValue: string;
  declare readonly boundaryValue: string;

  private interval: ReturnType<typeof setInterval> | undefined;
  private selectedSensor?: string;
  private boundHandleVisibilityChange?: () => void;
  private boundHandleDblClick?: (event: MouseEvent) => void;

  connect() {
    if (this.intervalValue) {
      this.boundHandleVisibilityChange = this.handleVisibilityChange.bind(this);
      document.addEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
      );
    }

    this.boundHandleDblClick = this.handleDblClick.bind(this);
    document.addEventListener('dblclick', this.boundHandleDblClick);

    this.startLoop();
  }

  disconnect() {
    this.stopLoop();

    if (this.boundHandleDblClick) {
      document.removeEventListener('dblclick', this.boundHandleDblClick);
    }

    if (this.boundHandleVisibilityChange)
      document.removeEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
      );
  }

  startLoop(event?: ActionEvent) {
    if (!this.intervalValue) return;

    this.stopLoop();

    if (event?.params?.sensor) this.selectedSensor = event.params.sensor;

    this.interval = setInterval(() => {
      // Move to next page when boundary is reached
      if (
        this.boundaryValue &&
        this.nextPathValue &&
        new Date() > new Date(this.boundaryValue)
      ) {
        Turbo.visit(this.nextPathValue);
        return;
      }

      // Otherwise, just reload the frame
      this.reloadFrames({ chart: this.reloadChartValue })
        .then(() => {
          // When no new chart has been loaded, add a new point to the existing chart
          if (!this.reloadChartValue) this.addPointToChart();
        })
        .catch((error) => {
          console.error(error);
          // Ignore error
        });
    }, this.intervalValue * 1000);
  }

  stopLoop() {
    if (this.isInLoop) clearInterval(this.interval);
    this.interval = undefined;
  }

  get isInLoop() {
    return !!this.interval;
  }

  handleVisibilityChange(): void {
    if (document.hidden) this.stopLoop();
    else
      this.reloadFrames({ chart: true })
        .then(() => this.startLoop())
        .catch((error) => console.error(error));
  }

  handleDblClick(event: MouseEvent) {
    if (this.hasCanvasTarget && event.target == this.canvasTarget)
      this.chart?.resetZoom();
  }

  addPointToChart() {
    if (
      this.chart == null ||
      this.currentValue == null ||
      this.currentTime == null ||
      this.lastTime == null
    )
      return;

    // Never add a point with a time older than the last time in the chart
    if (this.currentTime < this.lastTime) return;

    this.removeOutdatedPoints();
    this.addCurrentPoint(this.currentTime, this.currentValue);

    // Redraw the chart
    this.chart.update();
  }

  addCurrentPoint(time: number, value: number) {
    if (!this.chart?.data.labels) return;

    // First, add the time as a label
    this.chart.data.labels.push(time);

    // Second, add the value to the appropriate dataset
    // There may be two datasets: One for positive, one for negative values.
    // Write value to the appropriate dataset
    if (value > 0) {
      this.positiveDataset?.data.push(value);
      this.negativeDataset?.data.push(0);
    } else {
      this.negativeDataset?.data.push(value);
      this.positiveDataset?.data.push(0);
    }
  }

  // Remove oldest point (when older than one hour)
  removeOutdatedPoints() {
    if (!this.chart?.data.labels) return;

    const oldestLabel = this.chart.data.labels[0];
    const oldestDate = new Date(oldestLabel as Date).getTime();
    const now = new Date().getTime();
    const diffInSeconds = (now - oldestDate) / 1000;
    if (diffInSeconds <= 3600) return;

    // Remove label + value in all datasets
    this.chart.data.labels?.shift();
    this.chart.data.datasets.forEach((dataset) => {
      dataset.data.shift();
    });
  }

  async reloadFrames(options: { chart: boolean }) {
    try {
      const promises = [this.statsTarget.reload()];
      if (options.chart) promises.push(this.chartTarget.reload());

      await Promise.all(promises).then(() => {
        setTimeout(() => {
          application.controllers.forEach((controller) => {
            if (controller instanceof TippyController) controller.refresh();
          });
        }, 100);
      });
    } catch (error) {
      console.error(error);
    }
  }

  get chart(): Chart | undefined {
    if (!this.hasCanvasTarget) return undefined;

    return Chart.getChart(this.canvasTarget);
  }

  get currentValue(): number | undefined {
    if (this.currentElement?.dataset.value == null) return undefined;

    return parseFloat(this.currentElement.dataset.value);
  }

  get currentTime(): number | undefined {
    if (!this.currentElement?.dataset.time) return undefined;

    return parseInt(this.currentElement.dataset.time) * 1000;
  }

  get lastTime(): number | undefined {
    if (!this.chart?.data.labels) return undefined;

    return this.chart.data.labels.slice(-1)[0] as number;
  }

  get currentElement(): HTMLElement | undefined {
    // Select the current element from the currentTargets (by comparing sensor)
    const targets = this.currentTargets.filter((target) => {
      if (target.dataset.sensor)
        switch (this.effectiveSensor) {
          case 'battery_power':
            return (
              target.dataset.sensor === 'battery_charging_power' ||
              target.dataset.sensor === 'battery_discharging_power'
            );

          case 'grid_power':
            return (
              target.dataset.sensor === 'grid_import_power' ||
              target.dataset.sensor === 'grid_export_power'
            );

          default:
            return target.dataset.sensor.startsWith(this.effectiveSensor);
        }
    });

    if (targets.length)
      // Return the first element with a non-zero value, or the first element otherwise
      return (
        targets.find((t) => parseFloat(t.dataset.value ?? '') !== 0) ??
        targets[0]
      );

    return undefined;
  }

  // The positive dataset is where at least one positive value exist
  get positiveDataset() {
    return this.chart?.data.datasets.find((dataset) =>
      dataset.data.some((v) => typeof v === 'number' && v > 0),
    );
  }

  // The negative dataset is where at least one negative value exist
  get negativeDataset() {
    return this.chart?.data.datasets.find((dataset) =>
      dataset.data.some((v) => typeof v === 'number' && v < 0),
    );
  }

  get effectiveSensor(): string {
    return this.selectedSensor ?? this.sensorValue;
  }
}

import { Controller, ActionEvent } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { Chart, ChartDataset } from 'chart.js';
import { IntervalTimer } from '@/utils/intervalTimer';

type LineDatasetWithId = ChartDataset<'line'> & {
  id: string;
};

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
    sensorName: String,

    // Refresh interval in seconds
    interval: { type: Number, default: 5 },

    // Should the chart be reloaded when the page is reloaded?
    // If false, the chart will be updated by adding a new point
    reloadChart: { type: Boolean, default: false },
  };
  declare readonly sensorNameValue: string;
  declare readonly intervalValue: number;
  declare readonly reloadChartValue: boolean;

  private timer?: IntervalTimer;
  private selectedSensor?: string;
  private boundHandleVisibilityChange?: () => void;
  private boundHandleDblClick?: (event: MouseEvent) => void;
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

    this.boundHandleDblClick = this.handleDblClick.bind(this);
    document.addEventListener('dblclick', this.boundHandleDblClick);

    this.startLoop();
  }

  disconnect() {
    this.removeTimer();

    if (this.boundHandleDblClick) {
      document.removeEventListener('dblclick', this.boundHandleDblClick);
    }

    if (this.boundHandleVisibilityChange)
      document.removeEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
      );
  }

  reload() {
    this.reloadFrames({ chart: this.reloadChartValue })
      .then(() => {
        // When no new chart has been loaded, add a new point to the existing chart
        // Wait for the next repaint to ensure the new value is available in the DOM
        if (!this.reloadChartValue)
          requestAnimationFrame(() => this.addPointToChart());
      })
      .catch((error) => {
        console.error(error);
        // Ignore error
      });
  }

  createTimer() {
    // Create a timer to reload the frames
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

  startLoop(event?: ActionEvent) {
    if (!this.timer) return;

    // Remember the selected sensor (given via parameter)
    if (event?.params?.sensorName)
      this.selectedSensor = event.params.sensorName;

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
      this.chart === undefined ||
      this.currentValue === undefined ||
      this.currentTime === undefined ||
      this.lastPointTime === undefined
    ) {
      if (this.currentValue && !this.chart) {
        // We got a value, but no chart. Reload the frames to get the chart
        this.reloadFrames({ chart: true });
      }

      return;
    }

    // Never add a point with a time older than the last time in the chart
    if (this.currentTime < this.lastPointTime) return;

    this.removeOutdatedPoints();
    this.addCurrentPoints();

    // Redraw the chart
    this.chart.update();
  }

  addCurrentPoints() {
    if (!this.chart?.data.labels) return;

    // First, add the time as a label
    this.chart.data.labels.push(this.currentTime?.getTime());

    // For each current target, add the value to the corresponding chart dataset (if any)
    const datasets = this.chart.data.datasets as LineDatasetWithId[];
    for (const target of this.currentTargets) {
      const sensorName = target.dataset.sensorName;
      const rawValue = target.dataset.value;

      if (sensorName && rawValue !== undefined) {
        const dataset = datasets.find((ds) => ds.id === sensorName);
        if (dataset) {
          const value = Number.parseFloat(rawValue);
          dataset.data.push(value);
        }
      }
    }
  }

  // Remove oldest point (when older than one hour)
  removeOutdatedPoints() {
    if (!this.chart?.data.labels) return;

    const oldestLabel = this.chart.data.labels[0];
    const oldestDate = new Date(oldestLabel as Date).getTime();
    const now = Date.now();
    const diffInSeconds = (now - oldestDate) / 1000;
    if (diffInSeconds <= 3600) return;

    // Remove label + value in all datasets
    this.chart.data.labels?.shift();
    for (const dataset of this.chart.data.datasets) {
      dataset.data.shift();
    }
  }

  async reloadFrames(options: { chart: boolean }) {
    try {
      const promises = [this.statsTarget.reload()];
      if (options.chart) promises.push(this.chartTarget.reload());

      await Promise.all(promises);
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

    return Number.parseFloat(this.currentElement.dataset.value);
  }

  get currentTime(): Date | undefined {
    if (!this.currentElement?.dataset.time) return undefined;

    const seconds: number = Number(this.currentElement.dataset.time);
    return new Date(seconds * 1000);
  }

  get lastPointTime(): Date | undefined {
    if (!this.chart?.data.labels) return undefined;

    const lastLabel: number = this.chart.data.labels.at(-1) as number;
    return new Date(lastLabel);
  }

  get currentElement(): HTMLElement | undefined {
    // Select the current element from the currentTargets (by comparing sensor_name)
    const targets = this.currentTargets.filter((target) => {
      if (target.dataset.sensorName)
        switch (this.effectiveSensor) {
          case 'battery_power':
            return (
              target.dataset.sensorName === 'battery_charging_power' ||
              target.dataset.sensorName === 'battery_discharging_power'
            );

          case 'grid_power':
            return (
              target.dataset.sensorName === 'grid_import_power' ||
              target.dataset.sensorName === 'grid_export_power'
            );

          case 'inverter_power':
            return target.dataset.sensorName === 'inverter_power';

          default:
            return target.dataset.sensorName.startsWith(this.effectiveSensor);
        }
    });

    if (targets.length)
      // Return the first element with a non-zero value, or the first element otherwise
      return (
        targets.find((t) => Number.parseFloat(t.dataset.value ?? '') !== 0) ??
        targets[0]
      );

    return undefined;
  }

  get effectiveSensor(): string {
    return this.selectedSensor ?? this.sensorNameValue;
  }
}

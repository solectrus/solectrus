import { Controller, ActionEvent } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { Chart, ChartDataset } from 'chart.js';
import { IntervalTimer } from '@/utils/intervalTimer';

type LineDatasetWithId = ChartDataset<'line'> & {
  id: string;
};

type ObjectPoint = { x: number; y: number | null };

const ONE_HOUR_MS = 60 * 60 * 1000;

// Server-side `bridge_short_gaps` renders datasets as {x, y} objects when the
// source series contains nulls. Detect from the first item — Chart.js locks
// the parsing format from there.
const isObjectFormat = (point: unknown): point is ObjectPoint =>
  !!point && typeof point === 'object' && 'x' in point;

export default class extends Controller {
  static readonly targets = ['current', 'stats', 'chart', 'canvas', 'flash'];

  declare readonly hasCurrentTarget: boolean;
  declare readonly currentTargets: HTMLElement[];

  declare readonly hasChartTarget: boolean;
  declare readonly chartTarget: Turbo.FrameElement;

  declare readonly hasStatsTarget: boolean;
  declare readonly statsTarget: Turbo.FrameElement;

  declare readonly hasCanvasTarget: boolean;
  declare readonly canvasTarget: HTMLCanvasElement;

  declare readonly hasFlashTarget: boolean;
  declare readonly flashTarget: HTMLElement;

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
  private boundHandlePopState?: () => void;
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

    this.boundHandlePopState = this.handlePopState.bind(this);
    window.addEventListener('popstate', this.boundHandlePopState);

    this.startLoop();
  }

  disconnect() {
    this.removeTimer();

    if (this.boundHandleVisibilityChange)
      document.removeEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
      );

    if (this.boundHandlePopState)
      window.removeEventListener('popstate', this.boundHandlePopState);
  }

  async reload() {
    try {
      await this.reloadFrames({ chart: this.reloadChartValue });
    } catch (error) {
      console.error(error);
      return;
    }

    if (this.reloadChartValue) return;

    requestAnimationFrame(() => this.addPointToChart());
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

  // Load chart by setting the frame's src directly (avoids Turbo Frame Navigation issues in 8.0.21+).
  loadChart(event: ActionEvent) {
    // Let modifier/middle clicks behave like normal link navigation (new tab/window).
    if (
      event instanceof MouseEvent &&
      (event.metaKey ||
        event.ctrlKey ||
        event.shiftKey ||
        event.altKey ||
        event.button === 1)
    )
      return;

    event.preventDefault();

    // Support both link clicks and select option changes.
    const element = event.currentTarget as HTMLElement;
    const historyUrl =
      element.getAttribute('href') ||
      element.getAttribute('data-href') ||
      (element instanceof HTMLOptionElement ? element.value : undefined);
    if (!historyUrl) return;

    if (event.params?.sensorName) this.selectedSensor = event.params.sensorName;

    this.applyChartUrl(historyUrl, event.params?.chartUrl);
  }

  stopLoop() {
    this.shouldStopRequests = true;
    this.timer?.stop();
  }

  get isInLoop() {
    return this.timer?.isActive();
  }

  // Entry point for select-based navigation (home URL + chart URL).
  loadChartForUrl(historyUrl: string, chartUrl?: string, sensorName?: string) {
    if (sensorName) this.selectedSensor = sensorName;
    this.applyChartUrl(historyUrl, chartUrl);
  }

  private applyChartUrl(historyUrl: string, chartUrl?: string) {
    const resolvedChartUrl = this.resolveChartUrl(historyUrl, chartUrl);
    if (!resolvedChartUrl) return;

    if (this.hasChartTarget) {
      const currentSrc =
        this.chartTarget.getAttribute('src') || this.chartTarget.src;
      if (currentSrc) {
        const currentUrl = new URL(currentSrc, window.location.origin);
        if (currentUrl.toString() === resolvedChartUrl) {
          this.chartTarget.innerHTML = '';
          this.chartTarget.reload();
          this.updateHistoryUrl(historyUrl);
          return;
        }
      }

      this.chartTarget.innerHTML = '';
      this.chartTarget.src = resolvedChartUrl;
    }

    this.updateHistoryUrl(historyUrl);
  }

  private updateHistoryUrl(historyUrl: string) {
    const nextUrl = new URL(historyUrl, window.location.origin);
    if (nextUrl.toString() === window.location.href) return;

    window.history.pushState({}, '', nextUrl.toString());
  }

  private resolveChartUrl(
    historyUrl: string,
    chartUrl?: string,
  ): string | null {
    if (chartUrl) {
      return new URL(chartUrl, window.location.origin).toString();
    }

    const history = new URL(historyUrl, window.location.origin);
    return this.chartUrlFromFrame(history);
  }

  private chartUrlFromFrame(history: URL): string | null {
    if (!this.hasChartTarget) return null;

    const frameSrc =
      this.chartTarget.getAttribute('src') || this.chartTarget.src;
    if (!frameSrc) return null;

    const chart = new URL(frameSrc, window.location.origin);
    chart.search = history.search;
    return chart.toString();
  }

  handleVisibilityChange(): void {
    if (document.hidden) this.stopLoop();
    else
      this.reloadFrames({ chart: true })
        .then(() => this.startLoop())
        .catch((error) => console.error(error));
  }

  handlePopState(): void {
    Turbo.visit(window.location.href, { action: 'replace' });
  }

  addPointToChart() {
    const currentTime = this.currentTime;
    const lastPointTime = this.lastPointTime;

    if (
      this.chart === undefined ||
      currentTime === undefined ||
      lastPointTime === undefined
    ) {
      if (this.hasCurrentValues && !this.chart) {
        // We got a value, but no chart. Reload the frames to get the chart
        this.reloadFrames({ chart: true });
      }

      return;
    }

    // Never add a point with a time older than the last time in the chart
    if (currentTime < lastPointTime) return;

    this.flashRightEdge();

    this.removeOutdatedPoints(currentTime);
    this.addCurrentPoints();
    this.slideXAxisWindow(currentTime);
    this.chart.update();
  }

  flashRightEdge() {
    const area = this.chart?.chartArea;
    if (!area || !this.hasFlashTarget) return;

    const flash = this.flashTarget;
    flash.style.left = `${area.right}px`;
    flash.style.top = `${area.top}px`;
    flash.style.height = `${area.bottom - area.top}px`;
    flash.style.backgroundColor = this.flashColor;

    // Force reflow so the animation restarts on every tick
    flash.classList.remove('chart-flash-active');
    void flash.offsetWidth;
    flash.classList.add('chart-flash-active');
  }

  private get flashColor(): string {
    const datasets = (this.chart?.data.datasets ?? []) as LineDatasetWithId[];
    const dataset =
      datasets.find((ds) => ds.id === this.effectiveSensor) ?? datasets[0];
    const color = dataset?.borderColor ?? dataset?.backgroundColor;
    return typeof color === 'string' ? color : 'currentColor';
  }

  // Server-side `bridge_short_gaps` may render datasets as {x, y} objects
  // (when the source series contains nulls); Chart.js locks the parsing
  // format from the first item, so pushing a plain number into an
  // object-format dataset yields a silently invisible {x: null, y: null}.
  // Match the existing format per dataset.
  addCurrentPoints() {
    if (!this.chart?.data.labels) return;

    const xMs = this.currentTime?.getTime();

    // First, add the time as a label
    this.chart.data.labels.push(xMs);

    // For each current target, add the value to the corresponding chart dataset (if any)
    const datasets = this.chart.data.datasets as LineDatasetWithId[];
    for (const target of this.currentTargets) {
      const sensorName = target.dataset.sensorName;
      const rawValue = target.dataset.value;

      if (sensorName && rawValue !== undefined) {
        const dataset = datasets.find((ds) => ds.id === sensorName);
        if (dataset) {
          const value = Number.parseFloat(rawValue);
          if (!Number.isNaN(value)) {
            let normalizedValue = value;
            if (dataset.stack === 'usage') normalizedValue = -Math.abs(value);
            else if (dataset.stack === 'source')
              normalizedValue = Math.abs(value);

            const entry =
              isObjectFormat(dataset.data[0]) && xMs !== undefined
                ? { x: xMs, y: normalizedValue }
                : normalizedValue;
            dataset.data.push(entry);
          }
        }
      }
    }
  }

  // Slide the fixed 1-hour x-axis window forward so newly appended points
  // stay inside the visible range. Server-side rendering pins min/max to the
  // time of the initial request; without this update the window would freeze
  // and live points drift off the right edge.
  slideXAxisWindow(currentTime: Date) {
    const xScale = this.chart?.options.scales?.x;
    if (!xScale || xScale.min == null || xScale.max == null) return;

    const nowMs = currentTime.getTime();
    xScale.min = nowMs - ONE_HOUR_MS;
    xScale.max = nowMs;
  }

  // Drop points that fell out of the 1-hour window ending at currentTime.
  // Using currentTime (sensor time) keeps this in sync with slideXAxisWindow,
  // and the loop catches backlogs (e.g. after the tab was inactive).
  //
  // Plain-number datasets stay aligned with `labels` (1:1), so they shift
  // together. {x, y} datasets (produced by server-side `bridge_short_gaps`)
  // have their own timestamps and a shorter `data` array because null entries
  // are dropped — they must be filtered against their own `x`, not against
  // labels[0], otherwise still-valid leading points get shifted out.
  removeOutdatedPoints(currentTime: Date) {
    const data = this.chart?.data;
    if (!data?.labels) return;

    const cutoff = currentTime.getTime() - ONE_HOUR_MS;
    const plainDatasets = data.datasets.filter(
      (ds) => !isObjectFormat(ds.data[0]),
    );
    const objectDatasets = data.datasets.filter((ds) =>
      isObjectFormat(ds.data[0]),
    );

    while (data.labels.length) {
      const oldestMs = new Date(data.labels[0] as Date).getTime();
      if (oldestMs >= cutoff) break;

      data.labels.shift();
      for (const dataset of plainDatasets) dataset.data.shift();
    }

    for (const dataset of objectDatasets) {
      while (isObjectFormat(dataset.data[0]) && dataset.data[0].x < cutoff) {
        dataset.data.shift();
      }
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
    const elementTime = this.currentElement?.dataset.time;
    if (elementTime != null) {
      const seconds = Number(elementTime);
      if (!Number.isNaN(seconds)) return new Date(seconds * 1000);
    }

    const secondsList = this.currentTargets
      .map((target) => target.dataset.time)
      .filter((time): time is string => time != null)
      .map((time) => Number(time))
      .filter((time) => !Number.isNaN(time));

    if (!secondsList.length) return undefined;

    const latestSeconds = Math.max(...secondsList);
    return new Date(latestSeconds * 1000);
  }

  get lastPointTime(): Date | undefined {
    // When `bridge_short_gaps` server-side renders {x, y} points it drops
    // null entries from data while `labels` keeps every timeline timestamp,
    // so labels.at(-1) can be a phantom timestamp newer than the real last
    // sample. Prefer the dataset's own x; fall back to labels otherwise.
    const data = this.chart?.data;
    if (!data) return undefined;

    const labelMs = data.labels?.at(-1) as number | undefined;
    let maxMs: number | undefined;
    for (const ds of data.datasets) {
      const last = ds.data.at(-1);
      const ms = isObjectFormat(last) ? last.x : labelMs;
      if (typeof ms === 'number' && (maxMs === undefined || ms > maxMs))
        maxMs = ms;
    }
    return maxMs !== undefined ? new Date(maxMs) : undefined;
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

  get hasCurrentValues(): boolean {
    return this.currentTargets.some((target) => {
      const value = target.dataset.value;
      return value != null && value !== '';
    });
  }
}

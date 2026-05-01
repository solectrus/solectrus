import { Controller, type ActionEvent } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { Chart, ChartDataset } from 'chart.js';
import { IntervalTimer } from '@/utils/intervalTimer';

type LineDatasetWithId = ChartDataset<'line'> & {
  id: string;
};

type BucketStats = { sum: number; count: number };

const ONE_HOUR_MS = 60 * 60 * 1000;

// Mirror the server-side `aggregateWindow(every: 30s, fn: mean)` cadence used
// by Sensor::Query::Series for the P1H timeframe. Live ticks arrive at the
// poll interval (5–60s), but to stay visually consistent with the historical
// part of the curve we snap them onto the same 30s wallclock grid.
//
// Trade-off: bucketEnd is always 0–30s in the future relative to currentTime,
// while the x-axis max is pinned to currentTime. Chart.js clips the segment
// past the right edge — the open bucket's exact y-value isn't visible until
// the axis catches up. The right-edge flash compensates by signalling that a
// sample landed.
const LIVE_BUCKET_MS = 30 * 1000;

// Sensor names that aggregate two underlying directional sensors. Used by
// `matchesSensor` to keep flashColor and the element lookup in sync.
const SPLIT_SENSORS: Record<string, readonly string[]> = {
  battery_power: ['battery_charging_power', 'battery_discharging_power'],
  grid_power: ['grid_import_power', 'grid_export_power'],
};

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
  private liveBucketChart?: Chart;
  private liveBucketEndMs?: number;
  private liveBucketSamples = new Map<string, BucketStats>();

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

  private async reload() {
    await this.reloadFrames({ chart: this.reloadChartValue });

    if (this.reloadChartValue) return;

    requestAnimationFrame(() => this.addPointToChart());
  }

  private createTimer() {
    this.timer = new IntervalTimer(() => {
      if (this.shouldStopRequests) return;

      this.reload();
    }, this.intervalValue * 1000);
  }

  private removeTimer() {
    this.timer?.stop();
    this.timer = undefined;
  }

  private startLoop() {
    if (!this.timer) return;
    if (this.isInLoop) return;

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

  private stopLoop() {
    this.shouldStopRequests = true;
    this.timer?.stop();
  }

  private get isInLoop() {
    return this.timer?.isActive();
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

  private handleVisibilityChange(): void {
    if (document.hidden) {
      this.stopLoop();
      return;
    }

    this.reloadFrames({ chart: true }).then(() => {
      // The tab may have flipped back to hidden while reloadFrames was in
      // flight; don't kick off polling in the background.
      if (!document.hidden) this.startLoop();
    });
  }

  private handlePopState(): void {
    Turbo.visit(window.location.href, { action: 'replace' });
  }

  private addPointToChart() {
    const chart = this.chart;
    const currentTime = this.currentTime;
    const lastPointTime = this.lastPointTime;

    if (
      chart === undefined ||
      currentTime === undefined ||
      lastPointTime === undefined
    ) {
      if (this.hasCurrentValues && !chart) {
        // We got a value, but no chart. Reload the frames to get the chart
        this.reloadFrames({ chart: true });
      }

      return;
    }

    // A reload (e.g. after visibilitychange) replaces the Chart instance.
    // Drop any in-flight bucket state so the next sample opens a fresh bucket
    // on the new chart's grid instead of overwriting a server-rendered point.
    this.resetLiveBucketIfChartChanged(chart);

    const bucketEndMs = this.computeBucketEnd(currentTime.getTime());
    const lastLabelMs = lastPointTime.getTime();

    // Skip stale samples whose 30s bucket falls inside the historical part of
    // the curve. The `===` case is only allowed when it's our own open bucket;
    // otherwise we'd overwrite a server-aggregated mean with a single sample.
    if (bucketEndMs < lastLabelMs) return;
    if (bucketEndMs === lastLabelMs && this.liveBucketEndMs !== bucketEndMs)
      return;

    this.flashRightEdge();

    this.absorbPartialLastPoint(chart, bucketEndMs, lastLabelMs);
    this.removeOutdatedPoints(currentTime);
    this.upsertLiveBucket(chart, bucketEndMs);
    this.slideXAxisWindow(currentTime);
    chart.update();
  }

  // Flux's `aggregateWindow` clips the trailing bucket at `range.stop`
  // (= request time), so the chart's last server-rendered label sits at an
  // arbitrary sub-30s offset. Without this, the first live tick would push a
  // separate 30s-aligned bucket right next to it — producing a visible kink
  // and losing the partial's samples from the open bucket's mean. Snap the
  // partial label onto the 30s grid and seed the rolling mean with its value
  // weighted by the portion of the bucket already covered, so subsequent live
  // ticks converge toward the same mean Influx will return on a later reload.
  private absorbPartialLastPoint(
    chart: Chart,
    bucketEndMs: number,
    lastLabelMs: number,
  ) {
    if (this.liveBucketEndMs !== undefined) return;
    if (lastLabelMs % LIVE_BUCKET_MS === 0) return;
    const bucketStart = bucketEndMs - LIVE_BUCKET_MS;
    if (lastLabelMs <= bucketStart || lastLabelMs >= bucketEndMs) return;

    const labels = chart.data.labels;
    if (!labels?.length) return;

    labels[labels.length - 1] = bucketEndMs;

    const intervalMs = this.intervalValue * 1000;
    const weight = Math.max(
      1,
      Math.round((lastLabelMs - bucketStart) / intervalMs),
    );

    for (const dataset of chart.data.datasets as LineDatasetWithId[]) {
      const value = dataset.data.at(-1) as number | null;
      this.liveBucketSamples.set(
        dataset.id,
        value !== null
          ? { sum: value * weight, count: weight }
          : { sum: 0, count: 0 },
      );
    }
    this.liveBucketEndMs = bucketEndMs;
  }

  private flashRightEdge() {
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
    if (!datasets.length) return 'currentColor';

    const dataset =
      datasets.find((ds) => this.matchesSensor(ds.id)) ?? datasets[0];
    const color = dataset.borderColor ?? dataset.backgroundColor;
    return typeof color === 'string' ? color : 'currentColor';
  }

  // Single source of truth for "does this id/name belong to the current
  // sensor selection?" Used by both flashColor (dataset ids) and
  // currentElement (target sensor names) so the two always agree —
  // particularly on the inverter_power exact-match rule, which prevents
  // catching per-inverter ids like inverter_power_1.
  private matchesSensor(name: string | undefined): boolean {
    if (!name) return false;
    const candidates = SPLIT_SENSORS[this.effectiveSensor];
    if (candidates) return candidates.includes(name);
    if (this.effectiveSensor === 'inverter_power')
      return name === 'inverter_power';
    return name.startsWith(this.effectiveSensor);
  }

  // Matches the right edge of the Flux `aggregateWindow(every: 30s)` bucket
  // the server renders.
  private computeBucketEnd(timeMs: number): number {
    return (
      Math.floor(timeMs / LIVE_BUCKET_MS) * LIVE_BUCKET_MS + LIVE_BUCKET_MS
    );
  }

  private resetLiveBucketIfChartChanged(chart: Chart) {
    if (this.liveBucketChart === chart) return;
    this.liveBucketChart = chart;
    this.liveBucketEndMs = undefined;
    this.liveBucketSamples.clear();
  }

  // Pushes exactly one entry per dataset every tick — null when the value is
  // missing — so labels and dataset.data stay aligned.
  private upsertLiveBucket(chart: Chart, bucketEndMs: number) {
    const labels = chart.data.labels;
    if (!labels) return;

    const datasets = chart.data.datasets as LineDatasetWithId[];
    const targets = this.currentTargets;
    const isUpdate =
      this.liveBucketEndMs === bucketEndMs && labels.at(-1) === bucketEndMs;

    if (!isUpdate) {
      this.liveBucketEndMs = bucketEndMs;
      this.liveBucketSamples.clear();
      labels.push(bucketEndMs);
    }

    for (const dataset of datasets) {
      const sample = this.currentValueFor(dataset, targets);
      let stats = this.liveBucketSamples.get(dataset.id);
      if (!stats)
        this.liveBucketSamples.set(dataset.id, (stats = { sum: 0, count: 0 }));
      if (sample !== null) {
        stats.sum += sample;
        stats.count++;
      }
      const value = stats.count > 0 ? stats.sum / stats.count : null;
      if (isUpdate) dataset.data[dataset.data.length - 1] = value;
      else dataset.data.push(value);
    }
  }

  private currentValueFor(
    dataset: LineDatasetWithId,
    targets: HTMLElement[],
  ): number | null {
    const target = targets.find((t) => t.dataset.sensorName === dataset.id);
    const rawValue = target?.dataset.value;
    if (rawValue === undefined) return null;

    const value = Number.parseFloat(rawValue);
    if (Number.isNaN(value)) return null;

    if (dataset.stack === 'usage') return -Math.abs(value);
    if (dataset.stack === 'source') return Math.abs(value);
    return value;
  }

  // Slide the fixed 1-hour x-axis window forward so newly appended points
  // stay inside the visible range. Server-side rendering pins min/max to the
  // time of the initial request; without this update the window would freeze
  // and live points drift off the right edge.
  private slideXAxisWindow(currentTime: Date) {
    const xScale = this.chart?.options.scales?.x;
    if (!xScale || xScale.min == null || xScale.max == null) return;

    const nowMs = currentTime.getTime();
    xScale.min = nowMs - ONE_HOUR_MS;
    xScale.max = nowMs;
  }

  // Datasets stay 1:1 aligned with `labels`, so labels and every dataset
  // shift together when a point falls out of the rolling 1-hour window.
  private removeOutdatedPoints(currentTime: Date) {
    const data = this.chart?.data;
    if (!data?.labels) return;

    const cutoff = currentTime.getTime() - ONE_HOUR_MS;
    const datasets = data.datasets as LineDatasetWithId[];

    while (data.labels.length) {
      const oldestMs = new Date(data.labels[0] as Date).getTime();
      if (oldestMs >= cutoff) break;

      data.labels.shift();
      for (const dataset of datasets) dataset.data.shift();
    }
  }

  // Reloads run independently: a failed stats reload shouldn't abort the chart
  // reload, and vice versa. allSettled keeps both moving while still surfacing
  // errors to the console for debugging.
  private async reloadFrames(options: { chart: boolean }) {
    const reloads = [this.statsTarget.reload()];
    if (options.chart) reloads.push(this.chartTarget.reload());

    const results = await Promise.allSettled(reloads);
    for (const result of results) {
      if (result.status === 'rejected') console.error(result.reason);
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
    const labelMs = this.chart?.data.labels?.at(-1) as number | undefined;
    return typeof labelMs === 'number' ? new Date(labelMs) : undefined;
  }

  get currentElement(): HTMLElement | undefined {
    const targets = this.currentTargets.filter((t) =>
      this.matchesSensor(t.dataset.sensorName),
    );
    if (!targets.length) return undefined;

    // Prefer a non-zero reading so the tile doesn't show 0 when one direction
    // (e.g. battery_charging_power) is idle but the other has a value.
    return (
      targets.find((t) => Number.parseFloat(t.dataset.value ?? '') !== 0) ??
      targets[0]
    );
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

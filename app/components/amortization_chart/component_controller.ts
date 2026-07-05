import { Controller } from '@hotwired/stimulus';
import { debounce } from 'throttle-debounce';
import { isReducedMotion } from '@/utils/device';
import * as Turbo from '@hotwired/turbo';

import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  Tooltip,
  ChartEvent,
  ActiveElement,
  Plugin,
  ScriptableContext,
  Filler,
} from 'chart.js';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';
import zoomPlugin from 'chartjs-plugin-zoom';

import { applyCrosshairFix } from '../chart_loader/helpers/crosshair_fix';
import GenericChartTooltip from '../chart_loader/helpers/generic_chart_tooltip';

Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  Tooltip,
  Filler,
  CrosshairPlugin,
  zoomPlugin,
);

applyCrosshairFix();

interface AmortizationData {
  labels: number[];
  nominal: number[];
  degree: (number | null)[];
  projected: boolean[];
  todayYear: number;
  todayYearProgress: number;
  todayValue: number | null;
  todayDegree: number | null;
}

// One vertex of the line. x is the (fractional) year: an integer for a
// year-end mark, or year-1+progress for the synthetic "today" vertex.
interface ChartPoint {
  x: number;
  y: number;
  year: number | null;
  projected: boolean;
  degree: number | null;
  today: boolean;
}

type Rgb = [number, number, number];
const POSITIVE_COLOR: Rgb = [5, 150, 105];
const NEGATIVE_COLOR: Rgb = [220, 38, 38];
const TODAY_COLOR = '#4f46e5';

const rgb = (c: Rgb) => `rgb(${c.join(', ')})`;
const rgba = (c: Rgb, alpha: number) => `rgba(${c.join(', ')}, ${alpha})`;
const signalColor = (value: number): Rgb =>
  value < 0 ? NEGATIVE_COLOR : POSITIVE_COLOR;

export default class extends Controller<HTMLDivElement> {
  static readonly values = {
    currency: String,
    balanceLabel: String,
    todayLabel: String,
    degreeLabel: String,
  };

  static readonly targets = ['canvas', 'data'];

  declare readonly canvasTarget: HTMLCanvasElement;
  declare readonly dataTarget: HTMLScriptElement;

  declare currencyValue: string;
  declare balanceLabelValue: string;
  declare todayLabelValue: string;
  declare degreeLabelValue: string;

  private chart?: Chart<'line'>;
  private boundHandleThemeChange?: () => void;
  private boundHandleDblClick?: () => void;
  private boundHandleResize?: () => void;
  private genericTooltip?: GenericChartTooltip;
  private hatchPattern?: CanvasPattern | string;
  private hatchKey?: string;

  connect() {
    this.process();

    this.boundHandleThemeChange = () => {
      this.chart?.destroy();
      this.process();
    };
    document.addEventListener('theme:changed', this.boundHandleThemeChange);

    // Double-click resets a drag-zoom, like the other charts.
    this.boundHandleDblClick = () => this.chart?.resetZoom();
    this.canvasTarget.addEventListener('dblclick', this.boundHandleDblClick);

    // Rebuild on resize. The maximize/minimize buttons (chart-zoom controller)
    // dispatch a window resize. A plain chart.resize() cannot recover the
    // return from the fullscreen overlay: Chart.js' leftover inline canvas
    // height keeps the flex container inflated, so it just re-measures the
    // wrong size. Destroying first clears that inline size and lets the
    // container collapse to its natural height before we rebuild - the same
    // approach as the other charts. Skip the entry animation while resizing.
    this.boundHandleResize = debounce(100, () => {
      this.chart?.destroy();
      this.process({ animate: false });
    });
    window.addEventListener('resize', this.boundHandleResize);
  }

  disconnect() {
    if (this.boundHandleThemeChange)
      document.removeEventListener(
        'theme:changed',
        this.boundHandleThemeChange,
      );

    if (this.boundHandleDblClick)
      this.canvasTarget.removeEventListener(
        'dblclick',
        this.boundHandleDblClick,
      );

    if (this.boundHandleResize)
      window.removeEventListener('resize', this.boundHandleResize);

    this.chart?.destroy();
    this.genericTooltip?.destroy();
    this.genericTooltip = undefined;
  }

  private process({ animate = true }: { animate?: boolean } = {}) {
    const data = this.getData();
    if (!data) return;

    this.hatchPattern = undefined;
    this.hatchKey = undefined;

    const firstYear = data.labels[0];
    const lastYear = data.labels[data.labels.length - 1];
    if (firstYear === undefined || lastYear === undefined) return;

    const progress = Math.min(Math.max(data.todayYearProgress, 0), 1);
    // Each mark is the balance at the END of its year (x = year), so "today" -
    // a fraction of the way through the current year - sits at year-1+progress,
    // between the previous year-end and the current one.
    const todayX = data.todayYear - 1 + progress;

    // Split at "today": the measured half keeps the solid area, the projected
    // half gets a hatched area (like the PV forecast). Both share the today
    // vertex so the solid line runs continuously across the seam.
    const { measured, projected } = this.buildSeries(data, todayX);
    const series = [measured, projected];

    // Show only every n-th year label so they stay horizontal and never
    // overlap - roughly a dozen labels regardless of the period length.
    const labelStep = Math.max(1, Math.ceil(data.labels.length / 12));

    const rootStyle = window.getComputedStyle(document.documentElement);
    const cssVar = (name: string) => rootStyle.getPropertyValue(name).trim();
    const axisColor = cssVar('--chart-axis-color');
    const gridColor = cssVar('--chart-grid-color');
    const zeroLineColor = cssVar('--chart-zero-line-color');
    const pointBorderColor = cssVar('--chart-point-border');

    const pointAt = (context: ScriptableContext<'line'>) =>
      context.raw as ChartPoint;

    const drilldownYear = (element: ActiveElement): number | null => {
      const point = series[element.datasetIndex]?.[element.index];
      if (!point || point.today || point.year === null) return null;
      return point.year <= new Date().getFullYear() ? point.year : null;
    };

    // Shared per-point styling; only the area fill and the base point radius
    // differ between the measured and projected halves.
    const commonDataset = {
      fill: 'origin' as const,
      tension: 0.32,
      pointHoverRadius: (context: ScriptableContext<'line'>) =>
        pointAt(context).today ? 0 : 5,
      pointBackgroundColor: (context: ScriptableContext<'line'>) =>
        rgba(signalColor(pointAt(context).y), 1),
      pointBorderColor,
      pointBorderWidth: 1.5,
      borderColor: (context: ScriptableContext<'line'>) =>
        this.lineGradient(context.chart, data.nominal),
      borderWidth: 2.5,
    };

    this.chart = new Chart(this.canvasTarget, {
      type: 'line',
      data: {
        datasets: [
          {
            ...commonDataset,
            data: measured,
            pointRadius: (context: ScriptableContext<'line'>) =>
              pointAt(context).today ? 0 : 3,
            backgroundColor: (context: ScriptableContext<'line'>) =>
              this.areaGradient(context.chart),
          },
          ...(projected.length > 1
            ? [
                {
                  ...commonDataset,
                  data: projected,
                  pointRadius: (context: ScriptableContext<'line'>) =>
                    pointAt(context).today ? 0 : 2,
                  backgroundColor: (context: ScriptableContext<'line'>) =>
                    this.hatchFill(context.chart),
                },
              ]
            : []),
        ],
      },
      plugins: [this.todayLinePlugin(todayX, firstYear, lastYear)],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        // Track the nearest year by x without having to hit a point exactly.
        // One tooltip item, since each x lives in only one of the two halves.
        interaction: { mode: 'nearest', axis: 'x', intersect: false },
        animation:
          isReducedMotion() || !animate
            ? false
            : { duration: 800, easing: 'easeOutQuart' },
        onClick: (_event: ChartEvent, elements: ActiveElement[]) => {
          if (!elements.length) return;

          const year = drilldownYear(elements[0]);
          if (year) Turbo.visit(`/savings/${year}`);
        },
        onHover: (_event: ChartEvent, elements: ActiveElement[], chart) => {
          const drillable =
            elements.length > 0 && drilldownYear(elements[0]) !== null;
          chart.canvas.style.cursor = drillable ? 'pointer' : 'default';
        },
        scales: {
          x: {
            // Linear (not category) so the today vertex can sit at its true
            // fractional-year position between the year marks.
            type: 'linear',
            min: firstYear,
            max: lastYear,
            grid: { display: false },
            ticks: {
              color: axisColor,
              maxRotation: 0,
              autoSkip: false,
              stepSize: labelStep,
              // Only whole years get a label; the fractional today vertex none.
              callback: (value) =>
                Number.isInteger(Number(value)) ? String(value) : '',
            },
          },
          y: {
            grid: {
              // Highlight the zero line (= amortization threshold)
              color: (context) =>
                context.tick.value === 0 ? zeroLineColor : gridColor,
              lineWidth: (context) => (context.tick.value === 0 ? 2 : 1),
            },
            ticks: {
              color: axisColor,
              callback: (value) => this.formatCurrency(Number(value), true),
            },
          },
        },
        plugins: {
          // Hairline via chartjs-plugin-crosshair, using the same red default
          // line and free (non-snapping) tracking as the other charts. Its
          // option key is unknown to the Chart.js types here. Crosshair's own
          // drag-to-zoom stays off (it crashes on null points); chartjs-plugin-
          // zoom handles drag-to-zoom instead. Cross-chart sync stays off.
          ...({
            crosshair: {
              sync: { enabled: false },
              zoom: { enabled: false },
            },
            zoom: {
              zoom: { drag: { enabled: true }, mode: 'x' },
            },
          } as unknown as Record<string, never>),
          tooltip: {
            enabled: false,
            // Table-like HTML tooltip (label left, value right), shared with
            // the other charts. The callback lines are "Label: Value" and get
            // split into columns by the renderer. No color swatches.
            displayColors: false,
            external: (context) => this.getTooltip().render(context),
            // The today vertex belongs to both the measured and the projected
            // dataset, so a hover there yields two identical items. Keep only
            // the first item per x.
            filter: (item, index, items) =>
              items.findIndex((other) => other.parsed.x === item.parsed.x) ===
              index,
            callbacks: {
              // Marks are PV-year birthdays (and the leading start anchor), so
              // the title is just the year; the synthetic vertex is "today".
              title: (items) => {
                const point = items[0]?.raw as ChartPoint | undefined;
                if (!point) return '';
                if (point.today) return this.todayLabelValue;
                return point.year === null ? '' : String(point.year);
              },
              label: (item) => {
                const point = item.raw as ChartPoint;
                const amount = `${this.balanceLabelValue}: ${this.formatCurrency(item.parsed.y ?? 0)}`;

                if (point.degree == null) return amount;

                return [
                  amount,
                  `${this.degreeLabelValue}: ${this.formatPercent(point.degree)}`,
                ];
              },
            },
          },
        },
      },
    });
  }

  // Split the year-end balances at "today" into a measured and a projected
  // half that share a today vertex. The vertex y is the exact net position (so
  // it matches the KPI). The projected half stays empty when today lies outside
  // the drawn range.
  private buildSeries(
    data: AmortizationData,
    todayX: number,
  ): { measured: ChartPoint[]; projected: ChartPoint[] } {
    const points: ChartPoint[] = data.labels.map((year, index) => ({
      x: year,
      y: data.nominal[index],
      year,
      projected: data.projected[index],
      degree: data.degree[index],
      today: false,
    }));

    const firstYear = data.labels[0];
    const lastYear = data.labels[data.labels.length - 1];
    if (
      firstYear === undefined ||
      lastYear === undefined ||
      todayX < firstYear ||
      todayX > lastYear
    )
      return { measured: points, projected: [] };

    const before = points.filter((point) => point.x < todayX);
    const after = points.filter((point) => point.x > todayX);
    const today: ChartPoint = {
      x: todayX,
      y: data.todayValue ?? before[before.length - 1]?.y ?? after[0]?.y ?? 0,
      year: null,
      projected: false,
      degree: data.todayDegree,
      today: true,
    };

    return { measured: [...before, today], projected: [today, ...after] };
  }

  // Diagonal-line pattern for the projected (forecast) area, signalling
  // "outlook". It keeps the sign colors of the measured area: green hatch above
  // the zero line, red below. To split by value the tile spans the full chart
  // height and only repeats horizontally (repeat-x), aligned to the zero line;
  // it is cached per (height, zero position) and rebuilt on resize/theme change.
  private hatchFill(chart: Chart): CanvasPattern | string {
    const area = chart.chartArea;
    const yScale = chart.scales.y;
    const fallback = rgba(POSITIVE_COLOR, 0.4);
    if (!area || !yScale || area.bottom <= area.top) return fallback;

    const height = Math.ceil(area.bottom - area.top);
    const zeroY = Math.min(
      Math.max(yScale.getPixelForValue(0) - area.top, 0),
      height,
    );
    const key = `${height}:${Math.round(zeroY)}`;
    if (this.hatchPattern && this.hatchKey === key) return this.hatchPattern;

    const tile = 10;
    const canvas = document.createElement('canvas');
    canvas.width = tile;
    canvas.height = height;

    const context = canvas.getContext('2d');
    if (!context) return fallback;

    context.lineWidth = 1;
    const drawDiagonals = (color: string) => {
      context.strokeStyle = color;
      for (let y = -tile; y < height + tile; y += tile) {
        context.beginPath();
        context.moveTo(0, y + tile);
        context.lineTo(tile, y);
        context.stroke();
      }
    };

    context.save();
    context.beginPath();
    context.rect(0, 0, tile, zeroY);
    context.clip();
    drawDiagonals(rgba(POSITIVE_COLOR, 0.4));
    context.restore();

    context.save();
    context.beginPath();
    context.rect(0, zeroY, tile, height - zeroY);
    context.clip();
    drawDiagonals(rgba(NEGATIVE_COLOR, 0.4));
    context.restore();

    const pattern = chart.ctx.createPattern(canvas, 'repeat-x');
    if (!pattern) return fallback;
    // Shift the tile down so its top aligns with the chart area (and thus the
    // baked-in zero split lands on the actual zero line).
    if (typeof pattern.setTransform === 'function')
      pattern.setTransform(new DOMMatrix().translate(0, area.top));

    this.hatchPattern = pattern;
    this.hatchKey = key;
    return pattern;
  }

  private getData(): AmortizationData | undefined {
    if (this.dataTarget.textContent)
      return JSON.parse(this.dataTarget.textContent);
  }

  private getTooltip(): GenericChartTooltip {
    if (!this.genericTooltip) this.genericTooltip = new GenericChartTooltip();
    return this.genericTooltip;
  }

  private lineGradient(chart: Chart, values: number[]) {
    if (!this.hasDrawableArea(chart)) return rgb(POSITIVE_COLOR);

    const { gradient, zeroStop } = this.verticalGradient(chart);
    const min = Math.min(...values);
    const max = Math.max(...values);

    if (max > 0) {
      gradient.addColorStop(0, rgb(POSITIVE_COLOR));
      gradient.addColorStop(zeroStop, rgb(POSITIVE_COLOR));
    }
    if (min < 0) {
      gradient.addColorStop(zeroStop, rgb(NEGATIVE_COLOR));
      gradient.addColorStop(1, rgb(NEGATIVE_COLOR));
    }

    return gradient;
  }

  private areaGradient(chart: Chart) {
    if (!this.hasDrawableArea(chart)) return rgba(POSITIVE_COLOR, 0.18);

    const { gradient, zeroStop } = this.verticalGradient(chart);

    gradient.addColorStop(0, rgba(POSITIVE_COLOR, 0.32));
    gradient.addColorStop(zeroStop, rgba(POSITIVE_COLOR, 0.05));
    gradient.addColorStop(zeroStop, rgba(NEGATIVE_COLOR, 0.05));
    gradient.addColorStop(1, rgba(NEGATIVE_COLOR, 0.28));

    return gradient;
  }

  // A hidden or not-yet-laid-out container yields a zero-height chart area, so
  // the vertical gradient would divide by zero and Canvas rejects the
  // non-finite color stop. Fall back to a solid color until the chart has real
  // height; the ResizeObserver redraws it once the container becomes visible.
  private hasDrawableArea(chart: Chart): boolean {
    const area = chart.chartArea;
    return !!area && area.bottom > area.top;
  }

  // Vertical gradient spanning the chart area, plus the [0..1] stop where the
  // zero line sits - the shared basis for the line and area color splits.
  private verticalGradient(chart: Chart) {
    const { top, bottom } = chart.chartArea;
    const zeroY = chart.scales.y?.getPixelForValue(0) ?? bottom;
    const zeroStop = Math.min(Math.max((zeroY - top) / (bottom - top), 0), 1);
    const gradient = chart.ctx.createLinearGradient(0, top, 0, bottom);

    return { gradient, zeroStop };
  }

  private todayLinePlugin(
    todayX: number,
    firstYear: number,
    lastYear: number,
  ): Plugin<'line'> {
    return {
      id: 'amortizationTodayLine',
      afterDraw: (chart) => {
        if (todayX < firstYear || todayX > lastYear) return;

        const x = chart.scales.x?.getPixelForValue(todayX);
        if (x === undefined) return;

        const { ctx } = chart;
        const { top, bottom, left, right } = chart.chartArea;

        // When zoomed in, "today" can fall outside the visible range; don't
        // paint the marker into the axis padding.
        if (x < left || x > right) return;

        ctx.save();
        ctx.strokeStyle = TODAY_COLOR;
        ctx.lineWidth = 1.5;
        ctx.setLineDash([3, 4]);
        ctx.beginPath();
        ctx.moveTo(x, top);
        ctx.lineTo(x, bottom);
        ctx.stroke();

        ctx.setLineDash([]);
        ctx.font = '600 10px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        const paddingX = 6;
        const badgeHeight = 18;
        const textWidth = ctx.measureText(this.todayLabelValue).width;
        const badgeWidth = textWidth + paddingX * 2;
        const badgeX = Math.min(
          Math.max(x - badgeWidth / 2, chart.chartArea.left),
          chart.chartArea.right - badgeWidth,
        );
        const badgeY = top + 4;

        ctx.fillStyle = TODAY_COLOR;
        this.roundedRect(ctx, badgeX, badgeY, badgeWidth, badgeHeight, 4);
        ctx.fill();

        ctx.fillStyle = '#ffffff';
        ctx.fillText(
          this.todayLabelValue,
          badgeX + badgeWidth / 2,
          badgeY + badgeHeight / 2,
        );
        ctx.restore();
      },
    };
  }

  private roundedRect(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
    radius: number,
  ) {
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + width - radius, y);
    ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
    ctx.lineTo(x + width, y + height - radius);
    ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
    ctx.lineTo(x + radius, y + height);
    ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();
  }

  private formatCurrency(value: number, compact = false): string {
    return new Intl.NumberFormat(navigator.language.split('@')[0], {
      style: 'currency',
      currency: this.currencyValue,
      maximumFractionDigits: 0,
      notation: compact ? 'compact' : 'standard',
    }).format(value);
  }

  private formatPercent(value: number): string {
    return new Intl.NumberFormat(navigator.language.split('@')[0], {
      style: 'percent',
      maximumFractionDigits: 0,
    }).format(value / 100);
  }
}

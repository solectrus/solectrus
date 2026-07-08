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

import { applyChartDefaults } from '../chart_loader/helpers/chart_defaults';
import GenericChartTooltip from '../chart_loader/helpers/generic_chart_tooltip';

Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  Tooltip,
  Filler,
  CrosshairPlugin,
);

applyChartDefaults();

interface AmortizationData {
  labels: number[];
  nominal: number[];
  degree: (number | null)[];
  projected: boolean[];
  todayYear: number;
  todayYearProgress: number;
  todayValue: number | null;
  todayDegree: number | null;
  breakEvenX: number | null;
  breakEvenDate: string | null;
  breakEvenDuration: string | null;
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
  // Synthetic zero-crossing vertex at the exact break-even date, so the
  // smoothed line meets zero right under the break-even ring.
  breakEven: boolean;
}

// One line of an on-curve annotation label.
interface LabelLine {
  text: string;
  color: string;
  weight: number;
  size: number;
}

type Rgb = [number, number, number];
const POSITIVE_COLOR: Rgb = [5, 150, 105];
const NEGATIVE_COLOR: Rgb = [220, 38, 38];
// Below this chart width we drop non-essential annotations (mobile).
const COMPACT_WIDTH = 480;

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
    breakEvenLabel: String,
  };

  static readonly targets = ['canvas', 'data'];

  declare readonly canvasTarget: HTMLCanvasElement;
  declare readonly dataTarget: HTMLScriptElement;

  declare currencyValue: string;
  declare balanceLabelValue: string;
  declare todayLabelValue: string;
  declare degreeLabelValue: string;
  declare breakEvenLabelValue: string;

  // Intl formatters are expensive to construct and the annotation plugin's
  // afterDraw re-runs them every frame, so build each lazily and reuse it.
  private localeName = navigator.language.split('@')[0];
  private currencyFormatter?: Intl.NumberFormat;
  private percentFormatter?: Intl.NumberFormat;
  private currencyShortWhole?: Intl.NumberFormat;
  private currencyShortThousands?: Intl.NumberFormat;
  private currencySymbolParts?: { symbol: string; symbolFirst: boolean };

  private chart?: Chart<'line'>;
  private boundHandleThemeChange?: () => void;
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

    // Narrow charts (mobile) get the compact "K" currency on the y-axis.
    const containerWidth = this.element.clientWidth || 600;
    const compact = containerWidth < COMPACT_WIDTH;

    const rootStyle = window.getComputedStyle(document.documentElement);
    const cssVar = (name: string) => rootStyle.getPropertyValue(name).trim();
    const axisColor = cssVar('--chart-axis-color');
    const gridColor = cssVar('--chart-grid-color');
    const zeroLineColor = cssVar('--chart-zero-line-color');
    const pointBorderColor = cssVar('--chart-point-border');
    const accentColor = cssVar('--chart-accent-color');
    const strongColor = cssVar('--chart-label-strong');

    const pointAt = (context: ScriptableContext<'line'>) =>
      context.raw as ChartPoint;

    // Synthetic vertices (today, break-even) carry no visible dot; their
    // markers are drawn by the annotation plugin instead.
    const noMarker = (context: ScriptableContext<'line'>) => {
      const point = pointAt(context);
      return point.today || point.breakEven;
    };

    const drilldownYear = (element: ActiveElement): number | null => {
      const point = series[element.datasetIndex]?.[element.index];
      if (!point || point.today || point.year === null) return null;
      return point.year <= new Date().getFullYear() ? point.year : null;
    };

    // Shared per-point styling; only the area fill and the base point radius
    // differ between the measured and projected halves.
    const commonDataset = {
      fill: 'origin' as const,
      // Monotone (not tension) so the extra break-even vertex between two close
      // yearly points can't make the smoothed line overshoot into a kink.
      cubicInterpolationMode: 'monotone' as const,
      pointHoverRadius: (context: ScriptableContext<'line'>) =>
        noMarker(context) ? 0 : 5,
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
              noMarker(context) ? 0 : 3,
            backgroundColor: (context: ScriptableContext<'line'>) =>
              this.areaGradient(context.chart),
          },
          ...(projected.length > 1
            ? [
                {
                  ...commonDataset,
                  data: projected,
                  pointRadius: (context: ScriptableContext<'line'>) =>
                    noMarker(context) ? 0 : 2,
                  backgroundColor: (context: ScriptableContext<'line'>) =>
                    this.hatchFill(context.chart),
                },
              ]
            : []),
        ],
      },
      plugins: [
        this.annotationsPlugin(todayX, firstYear, lastYear, data, {
          neutral: pointBorderColor,
          muted: axisColor,
          accent: accentColor,
          strong: strongColor,
        }),
      ],
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
              font: { size: 14 },
              // Let Chart.js thin the year labels to the available width; the
              // explicit min/max plus includeBounds keep the first and last year
              // always visible.
              maxRotation: 0,
              autoSkip: true,
              autoSkipPadding: 16,
              includeBounds: true,
              // The scale-generated ticks are whole years; the fractional today
              // vertex is a data point, not a tick, so it never gets a label.
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
              font: { size: 14 },
              callback: (value) =>
                compact
                  ? this.formatCurrencyShort(Number(value))
                  : this.formatCurrency(Number(value)),
            },
          },
        },
        plugins: {
          // Hairline via chartjs-plugin-crosshair, using the same red default
          // line and free (non-snapping) tracking as the other charts. Its
          // option key is unknown to the Chart.js types here. Crosshair's own
          // drag-to-zoom stays off (it crashes on null points, and drag-to-zoom
          // adds no value on this smooth curve). Cross-chart sync stays off.
          ...({
            crosshair: {
              sync: { enabled: false },
              zoom: { enabled: false },
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
            // the first item per x, and never the invisible break-even vertex.
            filter: (item, index, items) =>
              (item.raw as ChartPoint).breakEven !== true &&
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
      breakEven: false,
    }));

    const firstYear = data.labels[0];
    const lastYear = data.labels[data.labels.length - 1];

    // Anchor the curve to the exact break-even (balance = 0). The line is only
    // sampled yearly and smoothed (tension), so without this vertex it would
    // cross zero a bit beside the break-even ring instead of right under it.
    const breakEvenX = data.breakEvenX;
    if (
      breakEvenX != null &&
      firstYear !== undefined &&
      lastYear !== undefined &&
      breakEvenX > firstYear &&
      breakEvenX < lastYear
    ) {
      const insertAt = points.findIndex((point) => point.x > breakEvenX);
      points.splice(insertAt === -1 ? points.length : insertAt, 0, {
        x: breakEvenX,
        y: 0,
        year: null,
        projected: breakEvenX > todayX,
        degree: null,
        today: false,
        breakEven: true,
      });
    }

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
      breakEven: false,
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
    if (!this.genericTooltip)
      // Tint the nominal balance value red/green by sign; other rows (the
      // degree) keep the default text color.
      this.genericTooltip = new GenericChartTooltip((context) => {
        if (context.label !== this.balanceLabelValue) return undefined;

        const y = context.dataPoint?.parsed.y;
        if (typeof y !== 'number') return undefined;

        return rgb(signalColor(y));
      });
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

  // The annotation layer: the key figures live directly on the curve instead of
  // in a separate stats panel - "today" (dashed line, badge, net position +
  // degree), the break-even point on the zero line, and the final balance at the
  // end of the period. Drawn after the datasets so nothing overpaints them.
  private annotationsPlugin(
    todayX: number,
    firstYear: number,
    lastYear: number,
    data: AmortizationData,
    colors: { neutral: string; muted: string; accent: string; strong: string },
  ): Plugin<'line'> {
    return {
      id: 'amortizationAnnotations',
      afterDraw: (chart) => {
        this.drawBreakEven(chart, data, colors);
        this.drawFinalPoint(chart, data, lastYear);
        this.drawToday(chart, todayX, firstYear, lastYear, data, colors);
      },
    };
  }

  // Ring marker where the balance crosses zero, plus a two-line label with the
  // localized break-even month. Skipped when break-even lies outside the drawn
  // (possibly zoomed) range.
  private drawBreakEven(
    chart: Chart<'line'>,
    data: AmortizationData,
    colors: { neutral: string; muted: string; accent: string },
  ) {
    if (data.breakEvenX == null) return;

    const { ctx } = chart;
    const { left, right } = chart.chartArea;
    const x = chart.scales.x?.getPixelForValue(data.breakEvenX);
    const y = chart.scales.y?.getPixelForValue(0);
    if (x === undefined || y === undefined || x < left || x > right) return;

    this.drawDot(ctx, x, y, 5, colors.neutral, {
      color: colors.accent,
      width: 2.4,
    });

    const lines: LabelLine[] = [
      {
        text: this.breakEvenLabelValue.toUpperCase(),
        color: colors.muted,
        weight: 600,
        size: 14,
      },
    ];
    if (data.breakEvenDate)
      lines.push({
        text: data.breakEvenDate,
        color: colors.muted,
        weight: 400,
        size: 16,
      });
    if (data.breakEvenDuration)
      lines.push({
        text: data.breakEvenDuration,
        color: colors.muted,
        weight: 400,
        size: 15,
      });

    // Below and to the right of the ring: that quadrant (below zero, after the
    // crossing) is empty, so the label clears the descending curve to the left.
    this.drawLabel(chart, lines, x + 6, y + 10, 'right', 'top');
  }

  // Filled dot at the last vertex, closing off the projection line. The final
  // balance itself is left to the tooltip, so no label is drawn here.
  private drawFinalPoint(
    chart: Chart<'line'>,
    data: AmortizationData,
    lastYear: number,
  ) {
    const value = data.nominal[data.nominal.length - 1];
    if (value == null) return;

    const { ctx } = chart;
    const x = chart.scales.x?.getPixelForValue(lastYear);
    const y = chart.scales.y?.getPixelForValue(value);
    if (x === undefined || y === undefined) return;
    if (x < chart.chartArea.left || x > chart.chartArea.right) return;

    this.drawDot(ctx, x, y, 4.5, rgb(signalColor(value)));
  }

  // Dashed vertical line, a grey uppercase "today" caption at the top and a
  // two-line callout with the current net position and amortization degree -
  // the same figures as the KPI rail, so the two always agree.
  private drawToday(
    chart: Chart<'line'>,
    todayX: number,
    firstYear: number,
    lastYear: number,
    data: AmortizationData,
    colors: { neutral: string; muted: string; accent: string; strong: string },
  ) {
    if (todayX < firstYear || todayX > lastYear) return;

    const { ctx } = chart;
    const { top, bottom, left, right } = chart.chartArea;
    const x = chart.scales.x?.getPixelForValue(todayX);
    if (x === undefined || x < left || x > right) return;

    ctx.save();
    ctx.strokeStyle = colors.accent;
    ctx.lineWidth = 1.5;
    ctx.setLineDash([3, 4]);
    ctx.beginPath();
    ctx.moveTo(x, top);
    ctx.lineTo(x, bottom);
    ctx.stroke();
    ctx.restore();

    // Caption at the top, just right of the line: grey uppercase, matching the
    // break-even label so the two markers read as a consistent pair.
    ctx.save();
    ctx.font = `600 14px ${Chart.defaults.font.family}`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    const captionText = this.todayLabelValue.toUpperCase();
    const captionWidth = ctx.measureText(captionText).width;
    const captionX = Math.min(x + 6, right - captionWidth);
    const captionTop = top + 4;
    ctx.fillStyle = colors.muted;
    ctx.fillText(captionText, captionX, captionTop);
    ctx.restore();

    // Callout: the amortization degree, just below the caption. It is the
    // headline "how far am I" figure - big, bold and in the strong near-black
    // foreground, with a small caption below.
    if (data.todayDegree == null) return;

    const lines: LabelLine[] = [
      {
        text: this.formatPercent(data.todayDegree),
        color: colors.strong,
        weight: 700,
        size: 30,
      },
      {
        text: this.degreeLabelValue.toLowerCase(),
        color: colors.muted,
        weight: 400,
        size: 15,
      },
    ];

    // Anchor the callout to whichever side of the today line has more room.
    const side = x > (left + right) / 2 ? 'left' : 'right';
    this.drawLabel(chart, lines, x, captionTop + 22, side, 'top');
  }

  // Filled marker dot, optionally ringed, used for the break-even and final
  // vertices.
  private drawDot(
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    radius: number,
    fill: string,
    stroke?: { color: string; width: number },
  ) {
    ctx.save();
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fillStyle = fill;
    ctx.fill();
    if (stroke) {
      ctx.strokeStyle = stroke.color;
      ctx.lineWidth = stroke.width;
      ctx.stroke();
    }
    ctx.restore();
  }

  // Draws a stack of short text lines near an anchor, clamped inside the chart
  // area. `side` decides the horizontal anchor; `baseline` its vertical origin.
  private drawLabel(
    chart: Chart<'line'>,
    lines: LabelLine[],
    px: number,
    py: number,
    side: 'left' | 'right',
    baseline: 'middle' | 'top' = 'middle',
  ) {
    if (!lines.length) return;

    const { ctx } = chart;
    const { left, right, top, bottom } = chart.chartArea;
    // Per-line vertical advance: keep the uniform 24 px rhythm for normal lines,
    // but give an oversized hero line (e.g. the amortization degree) the room it
    // needs so the line below never overlaps it.
    const lineHeights = lines.map((line) =>
      Math.max(24, Math.round(line.size * 1.2)),
    );
    const gap = 8;

    ctx.save();
    ctx.textBaseline = 'top';

    let widest = 0;
    for (const line of lines) {
      ctx.font = this.labelFont(line);
      widest = Math.max(widest, ctx.measureText(line.text).width);
    }

    let x: number;
    let align: CanvasTextAlign;
    if (side === 'left') {
      x = px - gap;
      align = 'right';
    } else {
      x = px + gap;
      align = 'left';
    }

    const blockHeight = lineHeights.reduce((sum, height) => sum + height, 0);
    let y = baseline === 'top' ? py : py - blockHeight / 2;
    y = Math.min(Math.max(y, top + 2), bottom - blockHeight);

    // Keep the whole block inside the plot horizontally.
    if (align === 'right') x = Math.max(x, left + widest);
    else x = Math.min(x, right - widest);

    ctx.textAlign = align;
    let offset = 0;
    lines.forEach((line, index) => {
      ctx.font = this.labelFont(line);
      ctx.fillStyle = line.color;
      ctx.fillText(line.text, x, y + offset);
      offset += lineHeights[index];
    });
    ctx.restore();
  }

  private labelFont(line: LabelLine): string {
    return `${line.weight} ${line.size}px ${Chart.defaults.font.family}`;
  }

  private formatCurrency(value: number): string {
    this.currencyFormatter ??= new Intl.NumberFormat(this.localeName, {
      style: 'currency',
      currency: this.currencyValue,
      maximumFractionDigits: 0,
    });
    return this.currencyFormatter.format(value);
  }

  // Compact axis labels with a "K" thousands suffix, e.g. "30K €" / "$30K".
  private formatCurrencyShort(value: number): string {
    const useK = Math.abs(value) >= 1000;
    this.currencyShortWhole ??= new Intl.NumberFormat(this.localeName, {
      maximumFractionDigits: 0,
    });
    this.currencyShortThousands ??= new Intl.NumberFormat(this.localeName, {
      maximumFractionDigits: 1,
    });
    const number =
      (useK ? this.currencyShortThousands : this.currencyShortWhole).format(
        useK ? value / 1000 : value,
      ) + (useK ? 'K' : '');

    const { symbol, symbolFirst } = this.currencySymbol();
    return symbolFirst ? `${symbol}${number}` : `${number} ${symbol}`;
  }

  // Currency symbol and its placement, derived once from the locale/currency.
  private currencySymbol(): { symbol: string; symbolFirst: boolean } {
    if (this.currencySymbolParts) return this.currencySymbolParts;

    const parts = new Intl.NumberFormat(this.localeName, {
      style: 'currency',
      currency: this.currencyValue,
      maximumFractionDigits: 0,
    }).formatToParts(0);
    const symbol = parts.find((part) => part.type === 'currency')?.value ?? '';
    const symbolFirst =
      parts.findIndex((part) => part.type === 'currency') <
      parts.findIndex((part) => part.type === 'integer');

    return (this.currencySymbolParts = { symbol, symbolFirst });
  }

  private formatPercent(value: number): string {
    this.percentFormatter ??= new Intl.NumberFormat(this.localeName, {
      style: 'percent',
      maximumFractionDigits: 0,
    });
    return this.percentFormatter.format(value / 100);
  }
}

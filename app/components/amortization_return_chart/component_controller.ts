import { Controller } from '@hotwired/stimulus';
import { debounce } from 'throttle-debounce';
import { isReducedMotion } from '@/utils/device';

import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Tooltip,
  Plugin,
  ScriptableContext,
  Filler,
} from 'chart.js';
import 'chartjs-adapter-luxon';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

import { applyChartDefaults } from '../chart_loader/helpers/chart_defaults';
import GenericChartTooltip from '../chart_loader/helpers/generic_chart_tooltip';

Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Tooltip,
  Filler,
  CrosshairPlugin,
);

applyChartDefaults();

interface ReturnHistoryData {
  // One sample per month end (plus today), x as an ISO date, y in % p.a.
  points: { x: string; y: number }[];
  // Calculatory interest rate the curve is measured against.
  rate: number;
  // Operating start as an ISO date - the axis begins here, a year before the
  // first sample, so the curve's late start stays visible.
  start: string | null;
}

// A sample with x turned into a timestamp, which is what the time scale and the
// pixel lookups in the annotation layer work with.
interface Sample {
  x: number;
  y: number;
}

type Rgb = [number, number, number];
const POSITIVE_COLOR: Rgb = [5, 150, 105];
const NEGATIVE_COLOR: Rgb = [220, 38, 38];
// Neutral slate for the band over the not-yet-evaluable first year. A fixed
// low-alpha tint rather than a theme variable: it has to stay a faint backdrop
// on both the white and the near-black canvas.
const BAND_COLOR = 'rgba(148, 163, 184, 0.14)';
// Below this band width the caption is dropped - a clipped or squeezed label
// reads worse than the bare tint.
const BAND_CAPTION_MIN_WIDTH = 110;

const rgb = (c: Rgb) => `rgb(${c.join(', ')})`;
const rgba = (c: Rgb, alpha: number) => `rgba(${c.join(', ')}, ${alpha})`;

export default class extends Controller<HTMLDivElement> {
  static readonly values = {
    returnLabel: String,
    emptyTitle: String,
    emptyBody: String,
  };

  static readonly targets = ['canvas', 'data'];

  declare readonly canvasTarget: HTMLCanvasElement;
  declare readonly dataTarget: HTMLScriptElement;

  declare returnLabelValue: string;
  declare emptyTitleValue: string;
  declare emptyBodyValue: string;

  // Intl formatters are expensive to construct and the annotation plugin
  // re-runs them every frame, so build each lazily and reuse it.
  private localeName = navigator.language.split('@')[0];
  private percentFormatter?: Intl.NumberFormat;
  private monthFormatter?: Intl.DateTimeFormat;

  private chart?: Chart<'line'>;
  private boundHandleThemeChange?: () => void;
  private boundHandleResize?: () => void;
  private genericTooltip?: GenericChartTooltip;
  // Last pointer position, recorded in the plugin's beforeEvent so it is set
  // before the tooltip decides what to show. Chart.js interaction is 'nearest'
  // on the x-axis, so without this a hover over the empty first-year band would
  // still pull up the first sample's tooltip.
  private pointerX: number | null = null;

  connect() {
    this.process();

    this.boundHandleThemeChange = () => {
      this.chart?.destroy();
      this.process();
    };
    document.addEventListener('theme:changed', this.boundHandleThemeChange);

    // Rebuild on resize (same reasoning as the balance chart): a plain
    // chart.resize() cannot recover the return from the fullscreen overlay,
    // because Chart.js' leftover inline canvas height keeps the flex container
    // inflated. Destroying first lets the container collapse to its natural
    // height before we rebuild.
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
    if (!data?.points.length) return;

    const samples: Sample[] = data.points.map(({ x, y }) => ({
      x: Date.parse(x),
      y,
    }));

    const rootStyle = window.getComputedStyle(document.documentElement);
    const cssVar = (name: string) => rootStyle.getPropertyValue(name).trim();
    const axisColor = cssVar('--chart-axis-color');
    const gridColor = cssVar('--chart-grid-color');
    const zeroLineColor = cssVar('--chart-zero-line-color');
    const pointBorderColor = cssVar('--chart-point-border');
    const accentColor = cssVar('--chart-accent-color');

    const lastPoint = samples[samples.length - 1];
    // Start the axis at the operating start when it is known, so the year
    // without evaluable data reads as a gap rather than being cropped away.
    const axisStart = data.start ? Date.parse(data.start) : undefined;

    this.chart = new Chart(this.canvasTarget, {
      type: 'line',
      data: {
        datasets: [
          {
            data: samples,
            // Monotone (not tension) so a sharp step - a repair booked in one
            // month - stays a step instead of overshooting into a dip.
            cubicInterpolationMode: 'monotone',
            borderColor: (context: ScriptableContext<'line'>) =>
              this.lineGradient(context.chart),
            borderWidth: 2.5,
            // Coloured by sign, never against the discount rate. The return is
            // the rate that zeroes the net present value and is therefore
            // independent of the calculatory one - tinting it against that
            // slider made a figure that provably does not move look as if it
            // had changed dramatically.
            fill: {
              value: 0,
              above: rgba(POSITIVE_COLOR, 0.18),
              below: rgba(NEGATIVE_COLOR, 0.18),
            },
            // Monthly samples would crowd the line with dots, so they only
            // appear on hover; the closing dot at today is drawn by the
            // annotation layer instead.
            pointRadius: 0,
            pointHoverRadius: () =>
              this.pointerInEmptyPeriod(samples) ? 0 : 4,
            pointBackgroundColor: (context: ScriptableContext<'line'>) =>
              this.signalColor(context.parsed?.y ?? 0),
            pointBorderColor,
            pointBorderWidth: 1.5,
          },
        ],
      },
      plugins: [
        this.annotationsPlugin(samples, data.rate, {
          accent: accentColor,
          neutral: pointBorderColor,
          muted: axisColor,
        }),
      ],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        // The curve ends on "today", i.e. exactly on the right edge, so its
        // marker dot needs room to spare or it would be sliced in half.
        layout: { padding: { right: 8 } },
        interaction: { mode: 'nearest', axis: 'x', intersect: false },
        animation:
          isReducedMotion() || !animate
            ? false
            : { duration: 800, easing: 'easeOutQuart' },
        scales: {
          x: {
            type: 'time',
            min: axisStart,
            time: { unit: 'month', tooltipFormat: 'MMMM yyyy' },
            grid: { display: false },
            ticks: {
              color: axisColor,
              font: { size: 14 },
              maxRotation: 0,
              autoSkip: true,
              autoSkipPadding: 16,
            },
          },
          y: {
            grid: {
              // Highlight the zero line - below it the system loses money in
              // absolute terms, not just against the discount rate.
              color: (context) =>
                context.tick.value === 0 ? zeroLineColor : gridColor,
              lineWidth: (context) => (context.tick.value === 0 ? 2 : 1),
            },
            ticks: {
              color: axisColor,
              font: { size: 14 },
              callback: (value) => this.formatPercent(Number(value)),
            },
          },
        },
        plugins: {
          // Hairline via chartjs-plugin-crosshair, matching the other charts.
          // Its option key is unknown to the Chart.js types here. Drag-to-zoom
          // and cross-chart sync stay off.
          ...({
            crosshair: {
              sync: { enabled: false },
              zoom: { enabled: false },
            },
          } as unknown as Record<string, never>),
          tooltip: {
            enabled: false,
            displayColors: false,
            external: (context) => this.getTooltip().render(context),
            // Over the empty first-year band there is nothing to report.
            // Dropping every item leaves an empty body, which the renderer
            // treats as "hide".
            filter: () => !this.pointerInEmptyPeriod(samples),
            callbacks: {
              title: (items) => {
                const parsed = items[0]?.parsed.x;
                return typeof parsed === 'number'
                  ? this.formatMonth(parsed)
                  : '';
              },
              label: (item) =>
                `${this.returnLabelValue}: ${this.formatPercent(item.parsed.y ?? 0)}`,
            },
          },
        },
      },
    });

    // Keep the final value reachable for screen readers and specs - the canvas
    // itself has no text.
    this.canvasTarget.setAttribute(
      'aria-label',
      `${this.returnLabelValue}: ${this.formatPercent(lastPoint.y)}`,
    );
  }

  private getData(): ReturnHistoryData | undefined {
    if (this.dataTarget.textContent)
      return JSON.parse(this.dataTarget.textContent);
  }

  private getTooltip(): GenericChartTooltip {
    if (!this.genericTooltip)
      // Tint the return by sign, matching the curve.
      this.genericTooltip = new GenericChartTooltip((context) => {
        const y = context.dataPoint?.parsed.y;
        if (typeof y !== 'number') return undefined;

        return this.signalColor(y);
      });
    return this.genericTooltip;
  }

  private signalColor(value: number): string {
    return rgb(value < 0 ? NEGATIVE_COLOR : POSITIVE_COLOR);
  }

  // Line colored by sign: green where the system earned a return at all, red
  // where it destroyed money. The comparison with the discount rate is left to
  // the dashed level - reading it off the line colour would make the curve
  // change with a slider it does not actually depend on.
  private lineGradient(chart: Chart) {
    const area = chart.chartArea;
    if (!area || area.bottom <= area.top) return rgb(POSITIVE_COLOR);

    const { top, bottom } = area;
    const zeroY = chart.scales.y?.getPixelForValue(0) ?? bottom;
    const stop = Math.min(Math.max((zeroY - top) / (bottom - top), 0), 1);

    const gradient = chart.ctx.createLinearGradient(0, top, 0, bottom);
    gradient.addColorStop(0, rgb(POSITIVE_COLOR));
    gradient.addColorStop(stop, rgb(POSITIVE_COLOR));
    gradient.addColorStop(stop, rgb(NEGATIVE_COLOR));
    gradient.addColorStop(1, rgb(NEGATIVE_COLOR));

    return gradient;
  }

  // The annotation layer: the not-yet-evaluable first year as a tinted band
  // behind the datasets, the discount rate as a bare dashed level, and a dot
  // closing off the curve at today. Only the band carries text - the rate is on
  // the slider above and the current return in the KPI rail of the chart view,
  // so repeating either here would only crowd the curve.
  private annotationsPlugin(
    samples: Sample[],
    rate: number,
    colors: { accent: string; neutral: string; muted: string },
  ): Plugin<'line'> {
    return {
      id: 'returnHistoryAnnotations',
      // beforeEvent fires before the tooltip plugin handles the same event, so
      // the recorded position is always current when the tooltip filter asks.
      beforeEvent: (_chart, args) => {
        this.pointerX = args.event.x;
      },
      beforeDatasetsDraw: (chart) =>
        this.drawEmptyPeriod(chart, samples, colors),
      afterDraw: (chart) => {
        this.drawReferenceLine(chart, rate, colors);
        this.drawCurrentPoint(chart, samples, rate, colors);
      },
    };
  }

  // Whether the pointer sits over the empty first-year band, i.e. left of the
  // first sample. There is no data there, so neither the tooltip nor a hover
  // dot should react.
  private pointerInEmptyPeriod(samples: Sample[]): boolean {
    const first = samples[0];
    if (!first || this.pointerX === null || !this.chart) return false;

    const x = this.chart.scales.x?.getPixelForValue(first.x);
    return x !== undefined && this.pointerX < x;
  }

  // The stretch between the operating start and the first evaluable date. The
  // axis deliberately spans the full operating time, so without this the year
  // reads as missing data rather than as "the figure could not be stated yet".
  private drawEmptyPeriod(
    chart: Chart<'line'>,
    samples: Sample[],
    colors: { muted: string },
  ) {
    const first = samples[0];
    if (!first) return;

    const { ctx } = chart;
    const { top, bottom, left } = chart.chartArea;
    const x = chart.scales.x?.getPixelForValue(first.x);
    if (x === undefined) return;

    const width = x - left;
    if (width < 2) return;

    ctx.save();
    ctx.fillStyle = BAND_COLOR;
    ctx.fillRect(left, top, width, bottom - top);
    ctx.restore();

    if (width < BAND_CAPTION_MIN_WIDTH) return;

    const centerX = left + width / 2;
    const centerY = (top + bottom) / 2;

    ctx.save();
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = colors.muted;
    ctx.font = `600 13px ${Chart.defaults.font.family}`;
    ctx.fillText(this.emptyTitleValue, centerX, centerY - 10);
    ctx.font = `400 13px ${Chart.defaults.font.family}`;
    ctx.fillText(this.emptyBodyValue, centerX, centerY + 10);
    ctx.restore();
  }

  // Where the fill flips from green to red. The y-axis is scaled to the curve,
  // so a low discount rate usually sits below the plot - then there is nothing
  // to draw and the whole area is simply above it.
  private drawReferenceLine(
    chart: Chart<'line'>,
    rate: number,
    colors: { accent: string },
  ) {
    const { ctx } = chart;
    const { top, bottom, left, right } = chart.chartArea;
    const y = chart.scales.y?.getPixelForValue(rate);
    if (y === undefined || y < top || y > bottom) return;

    ctx.save();
    ctx.strokeStyle = colors.accent;
    ctx.lineWidth = 1.5;
    ctx.setLineDash([3, 4]);
    ctx.beginPath();
    ctx.moveTo(left, y);
    ctx.lineTo(right, y);
    ctx.stroke();
    ctx.restore();
  }

  // Dot closing off the curve at the last sample, ringed in the sign color. It
  // sits exactly on the right edge of the plot, so the layout padding set above
  // is what keeps the whole circle on the canvas instead of slicing it in half.
  private drawCurrentPoint(
    chart: Chart<'line'>,
    samples: Sample[],
    rate: number,
    colors: { neutral: string },
  ) {
    const point = samples[samples.length - 1];
    if (!point) return;

    const { ctx } = chart;
    const x = chart.scales.x?.getPixelForValue(point.x);
    const y = chart.scales.y?.getPixelForValue(point.y);
    if (x === undefined || y === undefined) return;

    ctx.save();
    ctx.beginPath();
    ctx.arc(x, y, 5, 0, Math.PI * 2);
    ctx.fillStyle = colors.neutral;
    ctx.fill();
    ctx.strokeStyle = this.signalColor(point.y);
    ctx.lineWidth = 2.4;
    ctx.stroke();
    ctx.restore();
  }

  private formatPercent(value: number): string {
    this.percentFormatter ??= new Intl.NumberFormat(this.localeName, {
      style: 'percent',
      maximumFractionDigits: 1,
    });
    return this.percentFormatter.format(value / 100);
  }

  private formatMonth(value: number): string {
    this.monthFormatter ??= new Intl.DateTimeFormat(this.localeName, {
      month: 'long',
      year: 'numeric',
    });
    return this.monthFormatter.format(new Date(value));
  }
}

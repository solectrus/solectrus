import { Controller } from '@hotwired/stimulus';
import { isReducedMotion } from '@/utils/device';
import * as Turbo from '@hotwired/turbo';

import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Tooltip,
  ChartEvent,
  ActiveElement,
  Plugin,
  ScriptableContext,
  Filler,
} from 'chart.js';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

import { applyCrosshairFix } from '../chart_loader/helpers/crosshair_fix';
import GenericChartTooltip from '../chart_loader/helpers/generic_chart_tooltip';

Chart.register(
  LineController,
  LineElement,
  PointElement,
  CategoryScale,
  LinearScale,
  Tooltip,
  Filler,
  CrosshairPlugin,
);

applyCrosshairFix();

interface AmortizationData {
  labels: number[];
  nominal: number[];
  degree: (number | null)[];
  projected: boolean[];
  todayYear: number;
  todayYearProgress: number;
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
    endLabel: String,
  };

  static readonly targets = ['canvas', 'data'];

  declare readonly canvasTarget: HTMLCanvasElement;
  declare readonly dataTarget: HTMLScriptElement;

  declare currencyValue: string;
  declare balanceLabelValue: string;
  declare todayLabelValue: string;
  declare degreeLabelValue: string;
  declare endLabelValue: string;

  private chart?: Chart<'line'>;
  private boundHandleThemeChange?: () => void;
  private genericTooltip?: GenericChartTooltip;

  connect() {
    this.process();

    this.boundHandleThemeChange = () => {
      this.chart?.destroy();
      this.process();
    };
    document.addEventListener('theme:changed', this.boundHandleThemeChange);
  }

  disconnect() {
    if (this.boundHandleThemeChange)
      document.removeEventListener(
        'theme:changed',
        this.boundHandleThemeChange,
      );

    this.chart?.destroy();
    this.genericTooltip?.destroy();
    this.genericTooltip = undefined;
  }

  private process() {
    const data = this.getData();
    if (!data) return;

    const values = data.nominal;

    // Show only every n-th year label so they stay horizontal and never
    // overlap - roughly a dozen labels regardless of the period length.
    const labelStep = Math.max(1, Math.ceil(data.labels.length / 12));

    const rootStyle = window.getComputedStyle(document.documentElement);
    const cssVar = (name: string) => rootStyle.getPropertyValue(name).trim();
    const axisColor = cssVar('--chart-axis-color');
    const gridColor = cssVar('--chart-grid-color');
    const zeroLineColor = cssVar('--chart-zero-line-color');
    const pointBorderColor = cssVar('--chart-point-border');

    const colorFor = (index: number, alpha: number) =>
      rgba(signalColor(values[index] ?? 0), alpha);

    const drilldownYear = (index: number): number | null => {
      const year = data.labels[index];
      return year && year <= new Date().getFullYear() ? year : null;
    };

    this.chart = new Chart(this.canvasTarget, {
      type: 'line',
      data: {
        labels: data.labels,
        datasets: [
          {
            data: values,
            fill: 'origin',
            tension: 0.32,
            pointRadius: (context: ScriptableContext<'line'>) =>
              data.projected[context.dataIndex] ? 2 : 3,
            pointHoverRadius: 5,
            pointBackgroundColor: (context: ScriptableContext<'line'>) =>
              colorFor(context.dataIndex, 1),
            pointBorderColor,
            pointBorderWidth: 1.5,
            borderColor: (context: ScriptableContext<'line'>) =>
              this.lineGradient(context.chart, values),
            backgroundColor: (context: ScriptableContext<'line'>) =>
              this.areaGradient(context.chart),
            borderWidth: 2.5,
            segment: {
              borderColor: (context) =>
                rgb(
                  signalColor(context.p1.parsed.y ?? context.p0.parsed.y ?? 0),
                ),
              borderDash: (context) =>
                data.projected[context.p0DataIndex] ? [5, 5] : undefined,
            },
          },
        ],
      },
      plugins: [this.todayLinePlugin(data)],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        // Activate hover (tooltip + hairline) at the nearest x, without having
        // to hit a point exactly.
        interaction: { mode: 'index', intersect: false },
        animation: isReducedMotion()
          ? false
          : { duration: 800, easing: 'easeOutQuart' },
        onClick: (_event: ChartEvent, elements: ActiveElement[]) => {
          if (!elements.length) return;

          const year = drilldownYear(elements[0].index);
          if (year) Turbo.visit(`/savings/${year}`);
        },
        onHover: (_event: ChartEvent, elements: ActiveElement[], chart) => {
          const drillable =
            elements.length > 0 && drilldownYear(elements[0].index) !== null;
          chart.canvas.style.cursor = drillable ? 'pointer' : 'default';
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: {
              color: axisColor,
              maxRotation: 0,
              autoSkip: false,
              callback: (_value, index) =>
                index % labelStep === 0 ? data.labels[index] : '',
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
          // option key is unknown to the Chart.js types here. Drag-to-zoom and
          // cross-chart sync stay off.
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
            callbacks: {
              // Values are the balance on the last day of the year, so label
              // the title accordingly, e.g. "Ende 2032".
              title: (items) =>
                `${this.endLabelValue} ${items[0]?.label ?? ''}`.trim(),
              label: (item) => {
                const amount = `${this.balanceLabelValue}: ${this.formatCurrency(item.parsed.y ?? 0)}`;

                const degree = data.degree[item.dataIndex];
                if (degree == null) return amount;

                return [
                  amount,
                  `${this.degreeLabelValue}: ${this.formatPercent(degree)}`,
                ];
              },
            },
          },
        },
      },
    });
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

  private todayLinePlugin(data: AmortizationData): Plugin<'line'> {
    return {
      id: 'amortizationTodayLine',
      afterDraw: (chart) => {
        const firstYear = data.labels[0];
        const lastYear = data.labels[data.labels.length - 1];
        if (
          firstYear === undefined ||
          lastYear === undefined ||
          data.todayYear < firstYear ||
          data.todayYear > lastYear
        )
          return;

        const pointElements = chart.getDatasetMeta(0).data;
        const index = data.labels.indexOf(data.todayYear);
        const currentElement = pointElements[index];
        if (!currentElement) return;

        const previousElement = pointElements[index - 1];
        const nextElement = pointElements[index + 1];
        const progress = Math.min(Math.max(data.todayYearProgress, 0), 1);
        // Each mark is the balance at the END of its year, so "today" - a
        // fraction of the way through the current year - sits between the
        // previous year's mark and the current one. Interpolate there. When the
        // current year is the very first mark, there is no previous point to
        // anchor to, so use the forward gap as the year width and step back.
        const spacing = previousElement
          ? currentElement.x - previousElement.x
          : (nextElement?.x ?? currentElement.x) - currentElement.x;
        const anchorX = previousElement
          ? previousElement.x
          : currentElement.x - spacing;
        const x = anchorX + progress * spacing;
        const { ctx } = chart;
        const { top, bottom } = chart.chartArea;

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

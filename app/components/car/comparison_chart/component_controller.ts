import * as Turbo from '@hotwired/turbo';
import { debounce } from 'throttle-debounce';
import { isTouchEnabled } from '@/utils/device';
import { colorToRgba } from '@/utils/color';

import {
  Chart,
  BarController,
  BarElement,
  CategoryScale,
  LinearScale,
  Title,
  Tooltip,
  type ActiveElement,
  type ChartEvent,
} from 'chart.js';

import {
  handleTouchOrClick,
  touchTargetOf,
} from '../../chart_loader/helpers/interactions';
import {
  applyChartDefaults,
  chartContext,
} from '../../chart_loader/helpers/chart_defaults';
import ComparisonChartBase, {
  crosshair,
  fixYAxisWidth,
  swatchColors,
  Y_AXIS_WIDTH,
} from '../comparison_chart_base';

Chart.register(
  BarController,
  BarElement,
  CategoryScale,
  LinearScale,
  Title,
  Tooltip,
);

applyChartDefaults();

// A bar is 1.5 times as wide as its slot, so it covers a third of the next
const BAR_OVERLAP = 1.5;
const MAX_BAR_WIDTH = 40;

interface ComparisonData {
  // The label of each period on the axis, its title in the tooltip and the
  // path of its own comparison, only for the years
  labels: string[];
  titles: string[];
  paths?: string[];
  // Whether a period has fewer days than a whole one, so its bars are hatched
  partial: boolean[];
  // A bar for each column of the comparison, with its total cost
  series: { label: string; values: number[] }[];
}

// The cost of the three columns of the comparison with a combustion car for
// each period, as bars that overlap (see Car::ComparisonChart::Component).
// Chart.js draws the last dataset first, so the combustion car stands at the
// back and the car in front. A border in the color of the background parts
// the bars.
export default class extends ComparisonChartBase<ComparisonData, 'bar'> {
  static readonly values = { currency: String, title: String };
  static readonly targets = ['canvas', 'data', 'swatch'];

  declare readonly swatchTargets: HTMLElement[];
  declare titleValue: string;

  private width = 0;
  private lastTouchedTarget: string | null = null;

  // Only the width changes the bars (see #categoryPercentage). On iOS, the
  // toolbar changes the height while the page scrolls.
  private boundResize = debounce(100, () => {
    if (this.boxWidth() !== this.width) this.rebuild();
  });

  connect() {
    super.connect();
    window.addEventListener('resize', this.boundResize);
  }

  disconnect() {
    window.removeEventListener('resize', this.boundResize);
    super.disconnect();
  }

  protected process({ animate = true }: { animate?: boolean } = {}) {
    const data = this.getData();
    if (!data?.labels.length) return;

    const {
      tick: axisColor,
      grid: gridColor,
      zeroLine: zeroLineColor,
    } = this.axisColors();
    const colors = swatchColors(this.swatchTargets);
    const background = this.backgroundColor();
    const categoryPercentage = this.categoryPercentage(data);

    const context = chartContext(this.canvasTarget) ?? this.canvasTarget;
    this.chart = new Chart(context, {
      type: 'bar',
      data: {
        labels: data.labels,
        datasets: data.series.map((series, index) => {
          const hatch = this.hatchPattern(colors[index], background);
          const fill = data.partial.map((partial) =>
            partial ? hatch : colors[index],
          );
          return {
            label: series.label,
            data: series.values,
            backgroundColor: fill,
            hoverBackgroundColor: fill,
            borderRadius: 4,
            borderWidth: 2,
            borderColor: background,
            hoverBorderColor: background,
            categoryPercentage,
            barPercentage: BAR_OVERLAP,
          };
        }),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        // The tooltip shows the three bars of a period wherever the pointer
        // stands in it
        interaction: { mode: 'index', intersect: false },
        animation: this.animation(animate),
        // A tap on a touch device opens the tooltip of the year first, like
        // the other charts, and a second tap opens its comparison
        onClick: (_event: ChartEvent, elements: ActiveElement[]) => {
          const path = data.paths?.[elements[0]?.index ?? -1];
          if (!path) return;

          handleTouchOrClick(
            isTouchEnabled,
            this.touchTargetState(),
            touchTargetOf(elements[0]),
            () => Turbo.visit(path),
          );
        },
        onHover: (_event: ChartEvent, elements: ActiveElement[], chart) => {
          const drillable = data.paths && elements.length;
          chart.canvas.style.cursor = drillable ? 'pointer' : 'default';
        },
        scales: {
          x: {
            grid: { display: false },
            border: { color: gridColor },
            ticks: { color: axisColor, maxRotation: 0, autoSkip: true },
          },
          y: {
            // The axis ends just beyond the highest and the lowest bar,
            // without a label there. Otherwise it rounds to a whole step and
            // leaves the space empty. A negative cost is an income above the
            // energy cost.
            ...this.axisBounds(data),
            afterFit: fixYAxisWidth,
            grid: {
              color: (context) =>
                context.tick.value === 0 ? zeroLineColor : gridColor,
            },
            border: { display: false },
            ticks: {
              color: axisColor,
              maxTicksLimit: 6,
              includeBounds: false,
              callback: (value) => this.formatMoney(Number(value), 0),
            },
          },
        },
        plugins: {
          title: this.titleOptions(this.titleValue),
          // Other charts register chartjs-plugin-crosshair for all charts.
          // The bars of a period need no hairline.
          ...crosshair(false),
          tooltip: {
            enabled: false,
            displayColors: true,
            external: (context) => this.getTooltip().render(context),
            callbacks: {
              title: (items) => data.titles[items[0]?.dataIndex ?? -1] ?? '',
              label: (item) =>
                `${item.dataset.label}: ${this.formatMoney(item.parsed.y ?? 0, 0)}`,
              // The plain color of the column, also for a hatched bar
              labelColor: (item) => ({
                backgroundColor: colors[item.datasetIndex],
                borderColor: colors[item.datasetIndex],
              }),
            },
          },
        },
      },
    });
  }

  // The share of a period that its bars cover. A bar is wider than its slot
  // (see BAR_OVERLAP), so it reaches over the next one. A cap with
  // maxBarThickness would keep the slots and open gaps, so the share shrinks
  // instead, until a bar is MAX_BAR_WIDTH wide. The chart builds again on a
  // new width, so the width of the box is enough.
  private categoryPercentage(data: ComparisonData): number {
    this.width = this.boxWidth();
    const period = (this.width - Y_AXIS_WIDTH) / data.labels.length;
    const groupWidth = (MAX_BAR_WIDTH / BAR_OVERLAP) * data.series.length;

    return period > 0 ? Math.min(0.75, groupWidth / period) : 0.75;
  }

  private boxWidth(): number {
    return this.canvasTarget.parentElement?.clientWidth ?? 0;
  }

  // The color behind the chart. A card of a phone is translucent in dark
  // mode, so the backgrounds of the chart and of its parents mix on a canvas
  // of one pixel, from the outermost to the innermost.
  private backgroundColor(): string {
    const context = document.createElement('canvas').getContext('2d');
    if (!context) return 'transparent';

    const elements: HTMLElement[] = [];
    for (let el: HTMLElement | null = this.element; el; el = el.parentElement)
      elements.unshift(el);
    for (const el of elements) {
      context.fillStyle = window.getComputedStyle(el).backgroundColor;
      context.fillRect(0, 0, 1, 1);
    }

    const [red, green, blue] = context.getImageData(0, 0, 1, 1).data;
    return `rgb(${red}, ${green}, ${blue})`;
  }

  // Diagonal lines in the color of a column on a pale tint of it, for the
  // bars of a period with fewer days. The bars overlap, so the tint lies on
  // the background and hides the bar behind.
  private hatchPattern(
    color: string,
    background: string,
  ): CanvasPattern | string {
    const size = 8;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;

    const context = chartContext(canvas);
    if (!context) return color;

    context.fillStyle = background;
    context.fillRect(0, 0, size, size);
    context.fillStyle = colorToRgba(color, 0.25);
    context.fillRect(0, 0, size, size);

    context.strokeStyle = color;
    context.lineWidth = 1.5;
    context.beginPath();
    context.moveTo(0, size);
    context.lineTo(size, 0);
    // The corners continue the line into the next tiles
    context.moveTo(-1, 1);
    context.lineTo(1, -1);
    context.moveTo(size - 1, size + 1);
    context.lineTo(size + 1, size - 1);
    context.stroke();

    return context.createPattern(canvas, 'repeat') ?? color;
  }

  // The highest and the lowest value with a small margin, so the rounded end
  // of a bar stays whole. Without a negative value, the axis starts at 0.
  private axisBounds(data: ComparisonData): { min?: number; max?: number } {
    const values = data.series.flatMap((series) => series.values);
    const highest = Math.max(...values, 0);
    const lowest = Math.min(...values, 0);
    const margin = (highest - lowest) * 0.02;

    return {
      max: highest > 0 ? highest + margin : undefined,
      min: lowest < 0 ? lowest - margin : undefined,
    };
  }

  private touchTargetState() {
    return {
      get: () => this.lastTouchedTarget,
      set: (value: string | null) => {
        this.lastTouchedTarget = value;
      },
    };
  }
}

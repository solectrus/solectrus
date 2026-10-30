import { appLocale } from '@/utils/locale';

import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Tooltip,
} from 'chart.js';
import 'chartjs-adapter-luxon';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

import {
  applyChartDefaults,
  chartContext,
} from '../../chart_loader/helpers/chart_defaults';
import ComparisonChartBase, { crosshair } from '../comparison_chart_base';

Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Tooltip,
  CrosshairPlugin,
);

applyChartDefaults();

interface FuelPriceData {
  // A line for each fuel: x as an ISO date, y in currency per liter. Each
  // price holds until the next one, the last point closes the timeframe.
  lines: { label: string; points: { x: string; y: number }[] }[];
}

// The weekly prices of the fuel of the combustion car as a stepped line (see
// Car::FuelPriceChart::Component)
export default class extends ComparisonChartBase<FuelPriceData, 'line'> {
  static readonly values = { currency: String };
  static readonly targets = ['canvas', 'data'];

  private dateFormatter?: Intl.DateTimeFormat;

  protected process({ animate = true }: { animate?: boolean } = {}) {
    const data = this.getData();
    const lines = data?.lines.filter((line) => line.points.length) ?? [];
    if (!lines.length) return;

    const { tick: axisColor, grid: gridColor } = this.axisColors();
    // The red of the combustion car, from the text color of the element
    const lineColor = window.getComputedStyle(this.element).color;

    const xs = lines.flatMap((line) => line.points.map((p) => Date.parse(p.x)));
    const first = Math.min(...xs);
    const last = Math.max(...xs);

    const context = chartContext(this.canvasTarget) ?? this.canvasTarget;
    this.chart = new Chart(context, {
      type: 'line',
      data: {
        datasets: lines.map((line) => ({
          label: line.label,
          data: line.points.map((p) => ({ x: Date.parse(p.x), y: p.y })),
          // A price holds until the next one, so the line keeps it to the
          // next point before it jumps
          stepped: 'after' as const,
          borderColor: lineColor,
          borderWidth: 2.5,
          pointRadius: 0,
          pointHoverRadius: 4,
          pointBackgroundColor: lineColor,
        })),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: 'nearest', axis: 'x', intersect: false },
        animation: this.animation(animate),
        scales: {
          x: {
            type: 'time',
            min: first,
            max: last,
            adapters: { date: { locale: appLocale() } },
            grid: { display: false },
            border: { color: gridColor },
            ticks: {
              color: axisColor,
              maxRotation: 0,
              autoSkip: true,
              autoSkipPadding: 16,
            },
          },
          // From zero, like the chart of the energy cost, so the height of
          // the line shows the price and not its distance to the lowest one
          y: {
            beginAtZero: true,
            grid: { color: gridColor },
            border: { display: false },
            ticks: {
              color: axisColor,
              callback: (value) => this.formatMoney(Number(value), 2),
            },
          },
        },
        plugins: {
          // Hairline via chartjs-plugin-crosshair, like the other charts
          ...crosshair({ sync: { enabled: false }, zoom: { enabled: false } }),
          tooltip: {
            enabled: false,
            displayColors: false,
            external: (context) => this.getTooltip().render(context),
            callbacks: {
              title: (items) => {
                const x = items[0]?.parsed.x;
                return typeof x === 'number' ? this.formatDate(x) : '';
              },
              label: (item) =>
                `${item.dataset.label}: ${this.formatMoney(item.parsed.y ?? 0, 2)}/l`,
            },
          },
        },
      },
    });
  }

  private formatDate(value: number): string {
    this.dateFormatter ??= new Intl.DateTimeFormat(appLocale(), {
      dateStyle: 'medium',
    });
    return this.dateFormatter.format(value);
  }
}

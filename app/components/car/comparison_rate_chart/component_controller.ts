import { colorToRgba } from '@/utils/color';
import { appLocale } from '@/utils/locale';

import {
  Chart,
  Filler,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Title,
  Tooltip,
  type Scale,
} from 'chart.js';
import 'chartjs-adapter-luxon';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

import {
  applyChartDefaults,
  chartContext,
} from '../../chart_loader/helpers/chart_defaults';
import ComparisonChartBase, {
  crosshair,
  fixYAxisWidth,
  seriesHidden,
  seriesLabel,
  showsWithoutPv,
  swatchColors,
  type ColumnSeries,
} from '../comparison_chart_base';

Chart.register(
  Filler,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  TimeScale,
  Title,
  Tooltip,
  CrosshairPlugin,
);

applyChartDefaults();

// Up to half a year, a dot marks each week
const MAX_WEEKS_WITH_DOTS = 26;

interface RateData {
  // Each week with a distance: its first and its last date as ISO dates,
  // and its distance as text
  weeks: { from: string; to: string; distance: string }[];
  // With the chart of the periods above, the labels of its bar groups and
  // the position of each week on them: the index of its group plus its
  // share of the period
  labels?: string[];
  positions?: number[];
  // A line for each column with the cost of each week per 100 km
  series: ColumnSeries[];
}

// The position of each week on the x axis: on the bar groups above, or its
// first date
const positions = (data: RateData): number[] =>
  data.positions ?? data.weeks.map((week) => Date.parse(week.from));

// The points of a line. Until the page shows the car without PV, its line
// lies under the line of the car, with no area between them.
const points = (
  data: RateData,
  series: ColumnSeries,
  withoutPv: boolean,
  xs: number[],
) => {
  const values = seriesHidden(series, withoutPv)
    ? (data.series[0]?.values ?? [])
    : series.values;
  return values.map((y, week) => ({ x: xs[week] ?? 0, y }));
};

// The electricity cost of the cars and the fuel cost of the combustion car
// per 100 km for each week, as lines (see Car::ComparisonRateChart::Component)
export default class extends ComparisonChartBase<RateData, 'line'> {
  static readonly values = {
    currency: String,
    title: String,
    savingsLabel: String,
  };
  static readonly targets = ['canvas', 'data', 'swatch'];

  declare readonly swatchTargets: HTMLElement[];
  declare titleValue: string;
  declare savingsLabelValue: string;

  private dateFormatter?: Intl.DateTimeFormat;

  protected process({ animate = true }: { animate?: boolean } = {}) {
    const data = this.getData();
    if (!data?.weeks.length) return;

    const {
      tick: axisColor,
      grid: gridColor,
      zeroLine: zeroLineColor,
    } = this.axisColors();
    const withoutPv = showsWithoutPv(this.element);
    const colors = this.cachedColor('swatches', () =>
      swatchColors(this.swatchTargets),
    );
    // The car comes first, the combustion car last
    const combustion = data.series.length - 1;
    const weeks = data.weeks.length;
    const xs = positions(data);

    const context = chartContext(this.canvasTarget) ?? this.canvasTarget;
    this.chart = new Chart(context, {
      type: 'line',
      data: {
        datasets: data.series.map((series, index) => ({
          label: seriesLabel(series, withoutPv),
          data: points(data, series, withoutPv, xs),
          // The background colors the dots and the swatch of the tooltip
          borderColor: colors[index],
          backgroundColor: colors[index],
          borderWidth: 2.5,
          pointRadius: weeks > MAX_WEEKS_WITH_DOTS ? 0 : 3,
          pointHoverRadius: 4,
          fill: this.fill(index, colors),
        })),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        // The tooltip shows all lines of a week
        interaction: { mode: 'index', intersect: false },
        animation: this.animation(animate),
        // Under the bars, no padding for the line moves the plot area
        layout: { autoPadding: !data.labels },
        scales: {
          x: data.labels
            ? this.groupScale(data.labels, axisColor, gridColor)
            : {
                type: 'time',
                adapters: { date: { locale: appLocale() } },
                grid: { display: false },
                border: { color: gridColor },
                ticks: {
                  color: axisColor,
                  maxRotation: 0,
                  autoSkipPadding: 16,
                },
              },
          y: {
            // An energy has no income, so the axis starts at 0. Like the
            // chart of the periods, it ends just beyond the highest line,
            // without a label there.
            beginAtZero: true,
            max: this.axisMax(data),
            afterFit: fixYAxisWidth,
            grid: {
              color: (context) =>
                context.tick.value === 0 ? zeroLineColor : gridColor,
            },
            border: { display: false },
            ticks: {
              color: axisColor,
              maxTicksLimit: 6,
              // Whole steps, so no two labels round to the same amount
              precision: 0,
              includeBounds: false,
              callback: (value) => this.formatMoney(Number(value), 0),
            },
          },
        },
        plugins: {
          title: this.titleOptions(this.titleValue),
          // Hairline via chartjs-plugin-crosshair, like the other charts, but
          // in the color of the axis, because the red of the other charts
          // would look like a part of the line of the combustion car
          ...crosshair({
            line: { color: axisColor, width: 1 },
            sync: { enabled: false },
            zoom: { enabled: false },
          }),
          tooltip: {
            enabled: false,
            displayColors: true,
            external: (context) => this.getTooltip().render(context),
            // A line under the line of the car has no row
            filter: (item) =>
              data.series[item.datasetIndex]?.key !== 'without_pv' ||
              showsWithoutPv(this.element),
            callbacks: {
              title: (items) => {
                const week = data.weeks[items[0]?.dataIndex ?? -1];
                return week ? this.weekTitle(week) : '';
              },
              label: (item) =>
                `${item.dataset.label}: ${this.formatMoney(item.parsed.y ?? 0, 2)}`,
              // The savings of the week: the combustion car less the car,
              // the height of the area between the lines
              footer: (items) => {
                const week = items[0]?.dataIndex ?? -1;
                const car = data.series[0]?.values[week];
                const fuel = data.series[combustion]?.values[week];
                if (car === undefined || fuel === undefined) return '';

                return `${this.savingsLabelValue}: ${this.formatMoney(fuel - car, 2)}`;
              },
            },
          },
        },
      },
    });
  }

  // The page adds the car without PV or takes it away: its line rises from
  // the line of the car or sinks back to it (see points), and the car
  // changes its label. The line keeps showing, so its points move with an
  // animation and the area between the lines grows or shrinks with them.
  // Chart.js would only fade a hidden line.
  redraw() {
    const data = this.getData();
    if (!this.chart || !data) return;

    const withoutPv = showsWithoutPv(this.element);
    const xs = positions(data);
    data.series.forEach((series, index) => {
      const dataset = this.chart?.data.datasets[index];
      if (!dataset) return;

      dataset.label = seriesLabel(series, withoutPv);
      if (series.key === 'without_pv')
        dataset.data = points(data, series, withoutPv, xs);
    });
    this.chart.update();
  }

  // The area between the lines is the savings per 100 km: green where the
  // car costs less than the combustion car, red where it costs more. Each
  // line fills the area up to the next one, in the color of the car below
  // and of the next line above. Between two cars, the car without PV, a
  // stronger green shows the part of the savings that the PV system brings.
  private fill(index: number, colors: string[]) {
    const last = colors.length - 1;
    if (index === last) return false;

    return {
      target: '+1',
      below: colorToRgba(colors[0] ?? '', index + 1 < last ? 0.4 : 0.15),
      above: colorToRgba(colors[index + 1] ?? '', 0.15),
    };
  }

  // The axis of the bar groups of the chart of the periods: a group of the
  // same width for each period, with its label in the middle, like the
  // bars above
  private groupScale(labels: string[], axisColor: string, gridColor: string) {
    return {
      type: 'linear' as const,
      min: 0,
      max: labels.length,
      grid: { display: false },
      border: { color: gridColor },
      afterBuildTicks: (axis: Scale) => {
        axis.ticks = labels.map((_, index) => ({ value: index + 0.5 }));
      },
      ticks: {
        color: axisColor,
        maxRotation: 0,
        callback: (value: string | number) => labels[Math.floor(Number(value))],
      },
    };
  }

  // The dates of a week with its distance
  private weekTitle(week: RateData['weeks'][number]): string {
    this.dateFormatter ??= new Intl.DateTimeFormat(appLocale(), {
      dateStyle: 'medium',
    });
    const dates = this.dateFormatter.formatRange(
      Date.parse(week.from),
      Date.parse(week.to),
    );
    return `${dates} · ${week.distance}`;
  }

  private axisMax(data: RateData): number | undefined {
    const highest = Math.max(
      ...data.series.flatMap((series) => series.values),
      0,
    );

    return highest > 0 ? highest * 1.02 : undefined;
  }
}

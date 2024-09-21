import { Controller } from '@hotwired/stimulus';
import { debounce } from 'throttle-debounce';
import { isReducedMotion } from '@/utils/device';

import {
  Chart,
  LineElement,
  BarElement,
  PointElement,
  BarController,
  LineController,
  LinearScale,
  TimeScale,
  Filler,
  Title,
  Tooltip,
  ChartOptions,
  ChartType,
  ChartData,
  ChartDataset,
} from 'chart.js';

import 'chartjs-adapter-date-fns';
import { de } from 'date-fns/locale/de';
import zoomPlugin from 'chartjs-plugin-zoom';
import ChartBackgroundGradient from '@/utils/chartBackgroundGradient';

Chart.register(
  LineElement,
  BarElement,
  PointElement,
  BarController,
  LineController,
  LinearScale,
  TimeScale,
  Filler,
  Title,
  Tooltip,
  zoomPlugin,
);

export default class extends Controller<HTMLCanvasElement> {
  static readonly values = {
    type: String,
    unit: String,
  };

  static readonly targets = ['container', 'canvas', 'data', 'options'];

  declare readonly containerTarget: HTMLDivElement;
  declare readonly canvasTarget: HTMLCanvasElement;
  declare readonly dataTarget: HTMLScriptElement;
  declare readonly optionsTarget: HTMLScriptElement;

  declare readonly hasDataTarget: boolean;
  declare readonly hasOptionsTarget: boolean;

  declare typeValue: ChartType;
  declare readonly hasTypeValue: boolean;

  declare unitValue: string;
  declare readonly hasUnitValue: boolean;

  private boundHandleResize?: () => void;
  private chart?: Chart;

  connect() {
    this.process();

    this.boundHandleResize = debounce(100, this.handleResize.bind(this));
    window.addEventListener('resize', this.boundHandleResize);
  }

  disconnect() {
    if (this.boundHandleResize)
      window.removeEventListener('resize', this.boundHandleResize);

    if (this.chart) this.chart.destroy();
  }

  private handleResize() {
    // Disable animation when resizing
    document.body.classList.add('animation-stopper');

    if (this.chart) this.chart.destroy();
    this.process();

    setTimeout(() => {
      // Re-enable animation
      document.body.classList.remove('animation-stopper');
    }, 200);
  }

  private process() {
    const data = this.getData();
    if (!data) return;

    const options = this.getOptions();
    if (!options) return;

    // Disable animation when user prefers reduced motion
    if (isReducedMotion()) options.animation = false;

    if (!options.scales?.x || !options.scales?.y) return;

    // I18n
    // @ts-expect-error Property does not exist on type
    options.scales.x.adapters = {
      date: {
        locale: de,
      },
    };

    // Format numbers on y-axis
    if (options.scales.y.ticks)
      options.scales.y.ticks.callback = (value) =>
        typeof value === 'number' ? this.formattedNumber(value) : value;

    const max = this.maxOf(data);
    const min = this.minOf(data);
    if (min < 0) {
      // Disable auto-scaling if there are negative values
      options.scales.y.max = max;
      options.scales.y.min = min;

      // Draw x-axis in black
      options.scales.y.grid = {
        color: (context) => {
          if (context.tick.value === 0) return '#000';
        },
      };
    } else {
      options.scales.y.min =
        'suggestedMin' in options.scales.y && options.scales.y.suggestedMin
          ? Math.min(+options.scales.y.suggestedMin, min)
          : 0;
    }

    // Format numbers in tooltips
    if (options.plugins?.tooltip) {
      // Hide tooltip if value is null
      options.plugins.tooltip.filter = (tooltipItem): boolean => {
        if (Array.isArray(tooltipItem.raw))
          return tooltipItem.raw.filter((x) => x !== null).length > 0;

        return tooltipItem.raw !== null;
      };

      const isStacked = data.datasets.some((dataset) => dataset.stack);

      // Increase font size of tooltip footer (used for sum of stacked values)
      options.plugins.tooltip.footerFont = { size: 20 };

      options.plugins.tooltip.callbacks = {
        label: (tooltipItem) => {
          let result: string =
            !(isStacked && !tooltipItem.dataset.stack) &&
            data.datasets.length > 1
              ? `${tooltipItem.dataset.label} `
              : '';

          if (isStacked) {
            if (tooltipItem.dataset.stack && data.datasets.length) {
              // Sum is the value of the first dataset
              const sum = data.datasets[0].data[
                tooltipItem.dataIndex
              ] as number;

              if (sum)
                result += `${((tooltipItem.parsed.y * 100) / sum).toFixed(0)} %`;
            }
          } else {
            // Format value number
            result += tooltipItem.parsed._custom
              ? this.formattedInterval(
                  tooltipItem.parsed._custom.min,
                  tooltipItem.parsed._custom.max,
                )
              : this.formattedNumber(tooltipItem.parsed.y);
          }

          return result;
        },

        footer: (tooltipItems) => {
          if (isStacked && tooltipItems.length) {
            const sum = tooltipItems[0].parsed.y;

            if (sum) return this.formattedNumber(sum);
          }
        },
      };
    }

    if (max >= min)
      data.datasets.forEach((dataset: ChartDataset) => {
        // Non-Overlapping line charts should have a larger gradient (means lower opacity)
        const minAlpha =
          this.typeValue === 'line' && !this.isOverlapping(data.datasets)
            ? 0.04
            : 0.4;

        if (dataset.data)
          this.setBackgroundGradient(dataset, min, max, minAlpha);
      });

    this.chart = new Chart(this.canvasTarget, {
      type: this.typeValue,
      data,
      options,
    });
  }

  setBackgroundGradient(
    dataset: ChartDataset,
    min: number,
    max: number,
    minAlpha: number,
  ) {
    // Remember original color
    const originalColor = dataset.backgroundColor as string;

    const extent = min < 0 ? Math.abs(max) + Math.abs(min) : max;
    const basePosition = max / extent;
    const isNegative = dataset.data.some(
      (value) => typeof value === 'number' && value < 0,
    );

    const datasetMin = this.minOfDataset(dataset);
    const datasetMax = this.maxOfDataset(dataset);
    const datasetExtent =
      datasetMin < 0 ? Math.abs(datasetMax) + Math.abs(datasetMin) : datasetMax;

    const backgroundGradient = new ChartBackgroundGradient(
      originalColor,
      isNegative,
      basePosition,
      datasetExtent / extent,
      minAlpha,

      // Stacked bar must not be gradiented, just use the given Alpha
      dataset.stack ? minAlpha : 1,
    );

    // Replace background color with gradient
    dataset.backgroundColor = (context: { chart: Chart; type: string }) => {
      const { ctx, chartArea } = context.chart;

      if (chartArea) return backgroundGradient.canvasGradient(ctx, chartArea);
    };

    // Use original color for border
    dataset.borderColor = originalColor;
  }

  private getData(): ChartData | undefined {
    if (this.hasDataTarget && this.dataTarget.textContent)
      return JSON.parse(this.dataTarget.textContent);
  }

  private getOptions(): ChartOptions | undefined {
    if (this.hasOptionsTarget && this.optionsTarget.textContent)
      return JSON.parse(this.optionsTarget.textContent);
  }

  private formattedNumber(number: number) {
    return `${new Intl.NumberFormat().format(number)} ${this.unitValue}`;
  }

  private formattedInterval(min: number, max: number) {
    return `${this.formattedNumber(min)} - ${this.formattedNumber(max)}`;
  }

  // Get maximum value of all datasets, rounded up to next integer
  private maxOf(data: ChartData) {
    const flatData = this.flatMapped(data).map((value) =>
      Array.isArray(value) ? Math.max(...value) : value,
    );

    return Math.ceil(Math.max(...flatData));
  }

  // Get minium value of all datasets, rounded down to next integer
  private minOf(data: ChartData) {
    const flatData = this.flatMapped(data).map((value) =>
      Array.isArray(value) ? Math.min(...value) : value,
    );

    return Math.floor(Math.min(...flatData));
  }

  private flatMapped(data: ChartData) {
    return (
      data.datasets
        // Map all data into a single array
        .flatMap((dataset) => dataset.data)
        // Remove NULL values
        .filter((x) => x) as number[]
    );
  }

  private minOfDataset(dataset: ChartDataset) {
    const mapped = dataset.data
      .map((value) => (Array.isArray(value) ? Math.min(...value) : value))
      .filter((x) => x) as number[];

    return Math.min(...mapped);
  }

  private maxOfDataset(dataset: ChartDataset) {
    const mapped = dataset.data
      .map((value) => (Array.isArray(value) ? Math.max(...value) : value))
      .filter((x) => x) as number[];

    return Math.max(...mapped);
  }

  private isOverlapping(datasets: ChartDataset[]) {
    if (datasets.length <= 1) return false;
    if (datasets.length > 2) return true;

    if (!datasets[0].data || !datasets[1].data) return false;

    const data1 = datasets[0].data.filter((x) => x);
    const data2 = datasets[1].data.filter((x) => x);

    const firstAllPositive = data1.every(
      (value) => typeof value === 'number' && value >= 0,
    );
    const secondAllNegative = data2.every(
      (value) => typeof value === 'number' && value <= 0,
    );
    if (firstAllPositive && secondAllNegative) return false;

    const firstAllNegative = data1.every(
      (value) => typeof value === 'number' && value <= 0,
    );
    const secondAllPositive = data2.every(
      (value) => typeof value === 'number' && value >= 0,
    );
    if (firstAllNegative && secondAllPositive) return false;

    return true;
  }
}

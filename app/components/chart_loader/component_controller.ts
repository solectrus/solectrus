import { Controller } from '@hotwired/stimulus';
import { debounce } from 'throttle-debounce';

import {
  Chart,
  LineElement,
  BarElement,
  PointElement,
  BarController,
  LineController,
  LinearScale,
  TimeSeriesScale,
  Filler,
  Title,
  Tooltip,
  ChartOptions,
  ChartType,
  ChartData,
  ChartDataset,
} from 'chart.js';

import 'chartjs-adapter-date-fns';
import de from 'date-fns/locale/de';
import ChartBackgroundGradient from '@/utils/chartBackgroundGradient';

Chart.register(
  LineElement,
  BarElement,
  PointElement,
  BarController,
  LineController,
  LinearScale,
  TimeSeriesScale,
  Filler,
  Title,
  Tooltip,
);

export default class extends Controller<HTMLCanvasElement> {
  static values = {
    type: String,
    options: Object,
  };

  static targets = ['container', 'canvas', 'blank', 'json'];

  declare readonly containerTarget: HTMLDivElement;
  declare readonly canvasTarget: HTMLCanvasElement;
  declare readonly blankTarget: HTMLParagraphElement;
  declare readonly jsonTarget: HTMLScriptElement;

  declare readonly hasJsonTarget: boolean;

  declare typeValue: ChartType;
  declare readonly hasTypeValue: boolean;

  declare optionsValue: ChartOptions;
  declare readonly hasOptionsValue: boolean;

  private chart?: Chart;

  connect() {
    this.process();

    window.addEventListener(
      'resize',
      debounce(100, this.handleResize.bind(this)),
    );
  }

  disconnect() {
    window.removeEventListener('resize', this.handleResize.bind(this));

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

    if (!data || data.datasets.length === 0) {
      this.blankTarget.classList.remove('hidden');
      return;
    }

    this.containerTarget.classList.remove('hidden');

    const options = this.optionsValue;
    if (!options.scales?.x || !options.scales?.y) return;

    // I18n
    // @ts-ignore
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

      options.plugins.tooltip.callbacks = {
        label: (context) =>
          `${context.dataset.label}: ${
            context.parsed._custom
              ? this.formattedInterval(
                  context.parsed._custom.min,
                  context.parsed._custom.max,
                )
              : this.formattedNumber(context.parsed.y)
          }`,
      };
    }

    data.datasets.forEach((dataset: ChartDataset) =>
      this.setBackgroundGradient(dataset, min, max),
    );

    this.chart = new Chart(this.canvasTarget, {
      type: this.typeValue,
      data,
      options,
    });
  }

  setBackgroundGradient(dataset: ChartDataset, min: number, max: number) {
    // Remmeber original color
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
    if (this.hasJsonTarget)
      return JSON.parse(this.jsonTarget.textContent ?? '');
  }

  private formattedNumber(number: number) {
    return new Intl.NumberFormat().format(number);
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
}

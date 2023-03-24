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
} from 'chart.js';

import 'chartjs-adapter-date-fns';
import de from 'date-fns/locale/de';

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
    url: String,
    options: Object,
  };

  declare typeValue: ChartType;
  declare readonly hasTypeValue: boolean;

  declare urlValue: string;
  declare readonly hasUrlValue: boolean;

  declare optionsValue: ChartOptions;
  declare readonly hasOptionsValue: boolean;

  private chart: Chart | undefined;

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

  handleResize() {
    // Disable animation when resizing
    document.body.classList.add('animation-stopper');

    if (this.chart) this.chart.destroy();
    this.process();

    setTimeout(() => {
      // Re-enable animation
      document.body.classList.remove('animation-stopper');
    }, 200);
  }

  async process() {
    const data = await this.loadData();
    if (!data) return;

    const options = this.optionsValue;
    if (!options.scales?.x) return;
    if (!options.scales?.y) return;

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

    const min = this.minOf(data);
    if (min < 0) {
      // Disable auto-scaling if there are negative values
      options.scales.y.max = this.maxOf(data);
      options.scales.y.min = min;

      // Draw x-axis in black
      options.scales.y.grid = {
        color: (context) => {
          if (context.tick.value === 0) return '#000';
        },
      };
    } else {
      options.scales.y.min = 0;
    }

    // Format numbers in tooltips
    if (options.plugins?.tooltip)
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

    this.chart = new Chart(this.element, {
      type: this.typeValue,
      data,
      options,
    });
  }

  async loadData(): Promise<ChartData | undefined> {
    try {
      const response = await fetch(this.urlValue, {
        method: 'GET',
        headers: {
          accept: 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`Error! status: ${response.status}`);
      }

      return await response.json();
    } catch (err) {
      console.warn(err);
    }
  }

  formattedNumber(number: number) {
    return new Intl.NumberFormat().format(number);
  }

  formattedInterval(min: number, max: number) {
    return `${this.formattedNumber(min)} - ${this.formattedNumber(max)}`;
  }

  // Get maximum value of all datasets, rounded up to next integer
  maxOf(data: ChartData) {
    return Math.ceil(Math.max(...this.flatMapped(data)));
  }

  // Get minium value of all datasets, rounded down to next integer
  minOf(data: ChartData) {
    return Math.floor(Math.min(...this.flatMapped(data)));
  }

  flatMapped(data: ChartData) {
    return data.datasets.flatMap((dataset) => dataset.data as number[]);
  }
}

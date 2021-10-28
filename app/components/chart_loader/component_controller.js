import { Controller } from '@hotwired/stimulus';

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

export default class extends Controller {
  static values = {
    type: String,
    url: String,
    options: Object,
  };

  connect() {
    const that = this;
    fetch(this.urlValue)
      .then((response) => response.json())
      .then((data) => {
        const options = this.optionsValue;

        // I18n
        options.scales.x.adapters = {
          date: {
            locale: de,
          },
        };

        // Format numbers on y-axis
        options.scales.y.ticks.callback = (value) =>
          that.formattedNumber(value);

        const min = that.minOf(data);
        if (min < 0) {
          // Disable auto-scaling if there are negative values
          options.scales.y.max = that.maxOf(data);
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
        options.plugins.tooltip.callbacks = {
          label: (context) =>
            context.dataset.label +
            ': ' +
            that.formattedNumber(context.parsed.y),
        };

        this.chart = new Chart(this.element, {
          type: this.typeValue,
          data,
          options,
        });
      });
  }

  disconnect() {
    if (this.chart) this.chart.destroy();
  }

  formattedNumber(number) {
    return new Intl.NumberFormat().format(number);
  }

  // Get maximum value of all datasets, rounded up to next integer
  maxOf(data) {
    return Math.ceil(
      Math.max(...data.datasets.flatMap((dataset) => dataset.data)),
    );
  }

  // Get minium value of all datasets, rounded down to next integer
  minOf(data) {
    return Math.floor(
      Math.min(...data.datasets.flatMap((dataset) => dataset.data)),
    );
  }
}

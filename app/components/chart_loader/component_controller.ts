import { Controller } from '@hotwired/stimulus';
import { debounce } from 'throttle-debounce';
import { isReducedMotion, isTouchEnabled } from '@/utils/device';
import * as Turbo from '@hotwired/turbo';

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
  ChartEvent,
  ActiveElement,
} from 'chart.js';

import 'chartjs-adapter-luxon';
import zoomPlugin from 'chartjs-plugin-zoom';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

import ChartBackgroundGradient from '@/utils/chartGradientDefault';
import TemperatureGradient from '@/utils/chartGradientTemperature';

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
  CrosshairPlugin,
);

type DatasetWithId = ChartDataset & {
  id?: string;
};

// Fix for crosshair plugin drawing over the chart and tooltip
// https://github.com/AbelHeinsbroek/chartjs-plugin-crosshair/issues/48#issuecomment-1926758048
const afterDraw = CrosshairPlugin.afterDraw.bind(CrosshairPlugin);
CrosshairPlugin.afterDraw = () => {};
CrosshairPlugin.afterDatasetsDraw = (
  chart: Chart,
  args: unknown,
  options: unknown,
): void => {
  // @ts-expect-error Property does not exist on type
  if (chart?.crosshair) afterDraw(chart, args, options);
};

// Draw lines between points with no or null data (disables segmentation of the line)
Chart.overrides.line.spanGaps = true;

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

  private maxValue: number = 0;
  private minValue: number = 0;

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
    options.scales.x.adapters.date.locale = navigator.language || 'en';

    this.maxValue = this.maxOf(data);
    this.minValue = this.minOf(data);

    // Format numbers on y-axis
    if (options.scales.y.ticks)
      options.scales.y.ticks.callback = (value) =>
        typeof value === 'number' ? this.formattedNumber(value, 'axis') : value;

    if (this.minValue < 0) {
      // Draw x-axis in black
      options.scales.y.grid = {
        color: (context) => {
          return context.tick.value === 0 ? '#000' : 'rgba(0, 0, 0, 0.1)';
        },
      };
    }

    // Drill-down: Click on bars to navigate to a more detailed view
    let lastTouchedBar: number | null = null;
    options.onClick = (
      _event: ChartEvent,
      elements: ActiveElement[],
      chart: Chart,
    ) => {
      if (elements.length === 0 || !chart?.data?.labels) return;

      const dataIndex = elements[0].index;
      const barLabel = chart.data.labels[dataIndex];
      if (typeof barLabel !== 'number') return;

      if (isTouchEnabled()) {
        // To avoid conflict with tooltip, we wait for a second click
        if (lastTouchedBar === dataIndex) {
          handleDrilldown(barLabel);
          lastTouchedBar = null;
        } else {
          lastTouchedBar = dataIndex;
        }
      } else {
        handleDrilldown(barLabel);
      }
    };

    function handleDrilldown(barLabel: number) {
      const date = new Date(barLabel);
      const currentUrl = window.location.href;

      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');

      const drilldownLevels = [
        {
          regex: /(\/all)$/, // All → Year
          format: () => `${year}`,
        },
        {
          regex: /(\/\d{4}|\/year)$/, // Year → Month
          format: () => `${year}-${month}`,
        },
        {
          regex: /(\/\d{4}-\d{2}|\/month)$/, // Month → Day
          format: () => `${year}-${month}-${day}`,
        },
        {
          regex: /(\/\d{4}-W\d{2}|\/week)$/, // Week → Day
          format: () => `${year}-${month}-${day}`,
        },
        {
          regex: /(\/\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2})$/, // Range → Day
          format: () => `${year}-${month}-${day}`,
        },
        {
          regex: /(\/P\d{1,3}D)$/, // Days → Day
          format: () => `${year}-${month}-${day}`,
        },
        {
          regex: /(\/P\d{1,2}M)$/, // Months → Month
          format: () => `${year}-${month}`,
        },
        {
          regex: /(\/P\d{1,2}Y)$/, // Years → Year
          format: () => `${year}`,
        },
      ];

      for (const { regex, format } of drilldownLevels) {
        const match = regex.exec(currentUrl);
        const value = match?.[1];
        if (!value) continue;

        const formattedDate = format();
        const newUrl = currentUrl.replace(value, `/${formattedDate}`);
        Turbo.visit(newUrl);
        return;
      }

      console.warn('Unhandled drilldown path:', currentUrl);
    }

    options.onHover = (event: ChartEvent, elements: ActiveElement[]) => {
      if (event?.native?.target instanceof HTMLCanvasElement)
        event.native.target.style.cursor =
          elements.length && elements[0].element instanceof BarElement
            ? 'pointer'
            : 'default';
    };

    // Format numbers in tooltips
    if (options.plugins?.tooltip) {
      // Hide tooltip if value is null
      options.plugins.tooltip.filter = (tooltipItem): boolean => {
        if (Array.isArray(tooltipItem.raw))
          return tooltipItem.raw.filter((x) => x !== null).length > 0;

        return tooltipItem.raw !== null;
      };

      const isPowerSplitterStack = data.datasets.some(
        (dataset) => dataset.stack == 'Power-Splitter',
      );

      const isInverterStack = data.datasets.some(
        (dataset) => dataset.stack == 'InverterPower',
      );

      const isHeatingStack = data.datasets.some(
        (dataset) => dataset.stack == 'HeatingPower',
      );

      // Increase font size of tooltip footer (used for sum of stacked values)
      options.plugins.tooltip.footerFont = { size: 20 };

      // Reverse order of datasets in tooltip
      options.plugins.tooltip.itemSort = (a, b) =>
        b.datasetIndex - a.datasetIndex;

      options.plugins.tooltip.callbacks = {
        label: (tooltipItem) => {
          let result: string =
            !(
              (isPowerSplitterStack || isHeatingStack) &&
              !tooltipItem.dataset.stack
            ) && data.datasets.length > 1
              ? `${tooltipItem.dataset.label} `
              : '';

          if (isPowerSplitterStack || isHeatingStack) {
            if (tooltipItem.dataset.stack && data.datasets.length) {
              if (data.datasets.length == 2 || data.datasets.length == 3)
                // Now or Day
                result += this.formattedNumber(tooltipItem.parsed.y);
              else {
                // Sum is the value of the first dataset
                const sum = data.datasets[0].data[
                  tooltipItem.dataIndex
                ] as number;

                if (sum)
                  result += `${((tooltipItem.parsed.y * 100) / sum).toFixed(0)} %`;
              }
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
          let sum: number | undefined = undefined;

          if (isPowerSplitterStack && tooltipItems.length) {
            sum = tooltipItems.find((item) => {
              const id = (item.dataset as DatasetWithId).id;

              return id && !id.endsWith('_pv') && !id.endsWith('_grid');
            })?.parsed.y;

            if (sum) return this.formattedNumber(sum);
          } else if (isInverterStack && tooltipItems.length > 1) {
            sum = tooltipItems.reduce((acc, item) => {
              if (item.parsed.y) acc += item.parsed.y;
              return acc;
            }, 0);
          } else if (isHeatingStack) {
            if (tooltipItems.length == 4)
              // Week, Month, Year, All
              sum = tooltipItems[3].parsed.y;
            else if (tooltipItems.length == 3)
              // Now or Day
              sum = tooltipItems.reduce((acc, item) => {
                if (item.parsed.y) acc += item.parsed.y;
                return acc;
              }, 0);
          }

          if (sum) return this.formattedNumber(sum);
        },
      };
    }

    if (this.maxValue > this.minValue)
      data.datasets.forEach((dataset: ChartDataset) => {
        // Non-Overlapping line charts should have a larger gradient (means lower opacity)
        const minAlpha =
          this.typeValue === 'line' && !this.isOverlapping(data.datasets)
            ? 0.04
            : 0.4;

        if (!dataset.data) return;

        const id = (dataset as DatasetWithId).id;
        const isTemperature = id === 'case_temp' || id === 'outdoor_temp';

        if (isTemperature) {
          this.setTemperatureGradient(dataset);
        } else if (!Array.isArray(dataset.backgroundColor)) {
          // Apply gradient only when backgroundColor is a single color (not an array)
          this.setDefaultGradient(
            dataset,
            this.minValue,
            this.maxValue,
            minAlpha,
          );
        }
      });

    this.chart = new Chart(this.canvasTarget, {
      type: this.typeValue,
      data,
      options,
    });
  }

  private setDefaultGradient(
    dataset: ChartDataset,
    min: number,
    max: number,
    minAlpha: number,
  ) {
    const backgroundGradient = new ChartBackgroundGradient(
      dataset,
      min,
      max,
      minAlpha,
    );

    backgroundGradient.applyToDataset(dataset);
  }

  private setTemperatureGradient(dataset: ChartDataset) {
    const temperatureGradient = new TemperatureGradient(this.typeValue);
    temperatureGradient.applyToDataset(dataset);
  }

  private getData(): ChartData | undefined {
    if (this.hasDataTarget && this.dataTarget.textContent)
      return JSON.parse(this.dataTarget.textContent);
  }

  private getOptions(): ChartOptions | undefined {
    if (this.hasOptionsTarget && this.optionsTarget.textContent)
      return JSON.parse(this.optionsTarget.textContent);
  }

  private formattedNumber(
    number: number,
    target: 'axis' | 'tooltip' = 'tooltip',
  ) {
    let minValue: number;
    let maxValue: number;

    if (this.chart) {
      minValue = this.chart.scales.y.min;
      maxValue = this.chart.scales.y.max;
    } else {
      minValue = this.minValue;
      maxValue = this.maxValue;
    }

    let unitValuePrefix = '';

    const kilo =
      target === 'axis'
        ? maxValue > 1000 || minValue < -1000
        : number > 1000 || number < -1000;
    if (kilo) {
      number /= 1000.0;
      unitValuePrefix = 'k';
    }

    let decimals: number;
    if (kilo) {
      switch (target) {
        case 'tooltip':
          // On tooltip, we always want a precise value
          decimals = 3;
          break;
        case 'axis':
          // On axis, a single decimal is required to distinguish between values
          decimals = 1;
          break;
      }
    } else {
      // Without kilo, default to integers, unless unit is empty (dimensionless like COP) or °C
      decimals = this.unitValue == '' || this.unitValue == '°C' ? 1 : 0;
    }

    const numberAsString = new Intl.NumberFormat(navigator.language, {
      minimumFractionDigits: 0,
      maximumFractionDigits: decimals,
    }).format(number);

    return `${numberAsString} ${unitValuePrefix}${this.unitValue}`;
  }

  private formattedInterval(min: number, max: number) {
    return `${this.formattedNumber(min)} - ${this.formattedNumber(max)}`;
  }

  // Get maximum value of all datasets, summing only positive values per stack
  private maxOf(data: ChartData) {
    const stackSums: Record<string, number[]> = {};
    let maxSum = 0;

    data.datasets.forEach((dataset) => {
      const stackKey = dataset.stack ?? '__default'; // Fallback for not stacked datasets
      dataset.data?.forEach((value, index) => {
        const num = Array.isArray(value) ? Math.max(...value) : value;

        if (typeof num === 'number' && num > 0) {
          stackSums[stackKey] ??= [];
          stackSums[stackKey][index] = (stackSums[stackKey][index] ?? 0) + num;
          maxSum = Math.max(maxSum, stackSums[stackKey][index]);
        }
      });
    });

    return Math.ceil(maxSum);
  }

  // Get minimum value of all datasets, summing only negative values per stack
  private minOf(data: ChartData) {
    const stackSums: Record<string, number[]> = {};
    let minSum = 0;

    data.datasets.forEach((dataset) => {
      const stackKey = dataset.stack ?? '__default'; // Fallback for not stacked datasets
      dataset.data?.forEach((value, index) => {
        const num = Array.isArray(value) ? Math.min(...value) : value;

        if (typeof num === 'number' && num < 0) {
          stackSums[stackKey] ??= [];
          stackSums[stackKey][index] = (stackSums[stackKey][index] ?? 0) + num;
          minSum = Math.min(minSum, stackSums[stackKey][index]);
        }
      });
    });

    return Math.floor(minSum);
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

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
  ScatterController,
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
  Plugin,
  TooltipOptions,
  TooltipItem,
} from 'chart.js';

import 'chartjs-adapter-luxon';
import zoomPlugin from 'chartjs-plugin-zoom';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

import { buildCustomXAxisPlugin } from '@/utils/chartPluginCustomXAxis';
import PowerBalanceTooltip from './power_balance_tooltip';
import { applyCrosshairFix } from './crosshair_fix';
import { applyAxisStyles, getAxisColors } from './axis_styles';
import { ChartColorManager } from './color_scale';
import type {
  DatasetWithId,
  ExtendedTickOptions,
  TimeScaleOptions,
} from './types';

Chart.register(
  LineElement,
  BarElement,
  PointElement,
  BarController,
  LineController,
  ScatterController,
  LinearScale,
  TimeScale,
  Filler,
  Title,
  Tooltip,
  zoomPlugin,
  CrosshairPlugin,
);

applyCrosshairFix();

const isRecord = (value: unknown): value is Record<string, unknown> => {
  return value !== null && typeof value === 'object';
};

const isTooltipOptions = (
  tooltip: unknown,
): tooltip is TooltipOptions<ChartType> => {
  return isRecord(tooltip);
};

type TooltipConfig = NonNullable<
  NonNullable<ChartOptions['plugins']>['tooltip']
>;

// Draw lines between points with no or null data (disables segmentation of the line)
Chart.overrides.line.spanGaps = true;

export default class extends Controller<HTMLCanvasElement> {
  static readonly values = {
    type: String,
    unit: String,
    sourceLabel: String,
    usageLabel: String,
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

  declare sourceLabelValue: string;
  declare readonly hasSourceLabelValue: boolean;

  declare usageLabelValue: string;
  declare readonly hasUsageLabelValue: boolean;

  private boundHandleResize?: () => void;
  private boundHandleDblClick?: (event: MouseEvent) => void;
  private boundHandleThemeChange?: () => void;
  private chart?: Chart;
  private readonly colorManager = new ChartColorManager((datasets) =>
    this.isOverlapping(datasets),
  );
  private animationTimeout?: ReturnType<typeof setTimeout>;

  private maxValue: number = 0;
  private minValue: number = 0;
  private locale: string = 'en';
  private lastTouchedIndex: number | null = null;
  private powerBalanceTooltip?: PowerBalanceTooltip;

  private sanitizeLocale(locale: string): string {
    // Remove invalid suffixes like @posix that some browsers return
    // e.g., "en-US@posix" -> "en-US"
    return locale.split('@')[0];
  }

  connect() {
    this.process();

    this.boundHandleResize = debounce(100, this.handleResize.bind(this));
    window.addEventListener('resize', this.boundHandleResize);

    this.boundHandleDblClick = this.handleDblClick.bind(this);
    this.canvasTarget.addEventListener('dblclick', this.boundHandleDblClick);

    this.boundHandleThemeChange = this.handleThemeChange.bind(this);
    document.addEventListener('theme:changed', this.boundHandleThemeChange);
  }

  disconnect() {
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout);
      this.animationTimeout = undefined;
    }

    if (this.boundHandleResize)
      window.removeEventListener('resize', this.boundHandleResize);

    if (this.boundHandleDblClick)
      this.canvasTarget.removeEventListener(
        'dblclick',
        this.boundHandleDblClick,
      );

    if (this.boundHandleThemeChange)
      document.removeEventListener(
        'theme:changed',
        this.boundHandleThemeChange,
      );

    if (this.chart) this.chart.destroy();

    this.powerBalanceTooltip?.destroy();
    this.powerBalanceTooltip = undefined;
  }

  private handleResize() {
    // Disable animation when resizing
    document.body.classList.add('animation-stopper');

    if (this.chart) this.chart.destroy();
    this.process();

    this.animationTimeout = setTimeout(() => {
      // Re-enable animation
      document.body.classList.remove('animation-stopper');
    }, 200);
  }

  private handleThemeChange() {
    this.colorManager.clearCache();
    if (this.chart) this.chart.destroy();
    this.process();
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
    this.locale = this.sanitizeLocale(navigator.language) || 'en';
    // Set locale for time-based charts (skip for scatter charts with linear x-axis)
    const xScaleAsTime = options.scales.x as TimeScaleOptions;
    if (xScaleAsTime.adapters?.date) {
      xScaleAsTime.adapters.date.locale = this.locale;
    }

    this.maxValue = this.maxOf(data);
    this.minValue = this.minOf(data);

    const axisColors = getAxisColors(this.getCssVar.bind(this));
    applyAxisStyles(options, axisColors);
    const tooltip = options.plugins?.tooltip;
    if (isTooltipOptions(tooltip)) {
      const tooltipText = this.getCssVar('--chart-tooltip-text');
      tooltip.backgroundColor = this.getCssVar('--chart-tooltip-bg');
      tooltip.titleColor = tooltipText;
      tooltip.bodyColor = tooltipText;
      tooltip.footerColor = tooltipText;
      tooltip.borderColor = this.getCssVar('--chart-tooltip-border');
      tooltip.borderWidth = 1;
    }

    // Format numbers on y-axis
    const yTicks = options.scales.y.ticks as ExtendedTickOptions | undefined;
    if (yTicks?.callback === 'formatAbs') {
      options.scales.y.ticks!.callback = (value) =>
        typeof value === 'number'
          ? this.formattedNumber(Math.abs(value), 'axis')
          : value;
    } else if (yTicks && typeof yTicks.callback !== 'function') {
      options.scales.y.ticks!.callback = (value) =>
        typeof value === 'number' ? this.formattedNumber(value, 'axis') : value;
    }

    // Format temperature ticks on x-axis (for scatter charts)
    const xTicks = options.scales.x.ticks as ExtendedTickOptions | undefined;
    if (xTicks?.callback === 'formatTemperature') {
      options.scales.x.ticks!.callback = (value) =>
        typeof value === 'number' ? `${value.toFixed(1)} °C` : value;
    }

    // Highlight zero line on x-axis (vertical line at 0°C)
    if (
      options.scales.x.grid &&
      options.scales.x.grid.color === 'zeroLineHighlight'
    ) {
      const { grid, zeroLine } = axisColors;
      options.scales.x.grid.color = (context) =>
        context.tick.value === 0 ? zeroLine : grid;
    }

    // Format numbers on right y-axis (y1) for temperature
    if (options.scales.y1?.ticks) {
      options.scales.y1.ticks.callback = (value) =>
        typeof value === 'number' ? `${value} °C` : value;
    }

    if (this.minValue < 0) {
      // Draw x-axis in black
      const { grid, zeroLine } = axisColors;
      options.scales.y.grid = {
        color: (context) => {
          return context.tick.value === 0 ? zeroLine : grid;
        },
      };
    }

    // Drill-down: Click on bars/points to navigate to a more detailed view
    options.onClick = (
      _event: ChartEvent,
      elements: ActiveElement[],
      chart: Chart,
    ) => {
      if (elements.length === 0) return;

      const dataIndex = elements[0].index;
      const dataset = chart.data.datasets[
        elements[0].datasetIndex
      ] as DatasetWithId;

      // Check for drilldownPath in data point (e.g., scatter charts)
      const rawData = dataset.data?.[dataIndex] as
        | { drilldownPath?: string; timestamp?: number }
        | undefined;
      if (rawData?.drilldownPath) {
        this.handleTouchOrClick(dataIndex, () =>
          Turbo.visit(rawData.drilldownPath!),
        );
        return;
      }

      // Get timestamp from bar label
      if (!chart?.data?.labels) return;
      const barLabel = chart.data.labels[dataIndex];
      if (typeof barLabel !== 'number') return;

      this.handleTouchOrClick(dataIndex, () =>
        this.navigateToDrilldown(barLabel),
      );
    };

    options.onHover = (
      event: ChartEvent,
      elements: ActiveElement[],
      chart: Chart,
    ) => {
      if (!(event?.native?.target instanceof HTMLCanvasElement)) return;

      let showPointer = false;
      if (elements.length) {
        // Show pointer for bar elements
        if (elements[0].element instanceof BarElement) {
          showPointer = true;
        }
        // Show pointer for data points with drilldownPath
        const dataset = chart.data.datasets[elements[0].datasetIndex];
        const rawData = dataset.data?.[elements[0].index] as
          | { drilldownPath?: string }
          | undefined;
        if (rawData?.drilldownPath) {
          showPointer = true;
        }
      }

      event.native.target.style.cursor = showPointer ? 'pointer' : 'default';
    };

    this.configureTooltip(options, data);

    this.colorManager.setChartType(this.typeValue);
    this.colorManager.applyDatasetColors(data, this.minValue, this.maxValue);

    const plugins = this.buildCustomPlugins(options);

    this.chart = new Chart(this.canvasTarget, {
      type: this.typeValue,
      data,
      options,
      plugins,
    });
  }

  private buildCustomPlugins(options: Record<string, unknown>): Plugin[] {
    return buildCustomXAxisPlugin(options);
  }

  private configureTooltip(options: ChartOptions, data: ChartData): void {
    const tooltip = options.plugins?.tooltip;
    if (!tooltip) return;

    tooltip.filter = (tooltipItem): boolean => {
      if (Array.isArray(tooltipItem.raw))
        return tooltipItem.raw.filter((value) => value !== null).length > 0;
      return tooltipItem.raw !== null;
    };

    const flags = this.getTooltipFlags(data);

    tooltip.footerFont = { size: 20 };

    if (!flags.isPowerBalance) {
      tooltip.itemSort = (a, b) => b.datasetIndex - a.datasetIndex;
    }

    this.configurePowerBalanceTooltip(tooltip, flags);
    this.configureTooltipCallbacks(tooltip, data, flags);
  }

  private getTooltipFlags(data: ChartData) {
    const isPowerSplitterStack = data.datasets.some(
      (dataset) => dataset.stack == 'Power-Splitter',
    );
    const isInverterStack = data.datasets.some(
      (dataset) => dataset.stack == 'InverterPower',
    );
    const isHeatingStack = data.datasets.some(
      (dataset) => dataset.stack == 'HeatingPower',
    );

    return {
      isPowerSplitterStack,
      isInverterStack,
      isHeatingStack,
      ...this.getPowerBalanceConfig(data),
    };
  }

  private configurePowerBalanceTooltip(
    tooltip: TooltipConfig,
    flags: {
      isPowerBalance: boolean;
      sourceIds: Set<string>;
      usageIds: Set<string>;
      orderMap: Map<string, number>;
    },
  ): void {
    if (flags.isPowerBalance) {
      if (!this.powerBalanceTooltip) {
        const useKilo = this.typeValue !== 'line';
        this.powerBalanceTooltip = new PowerBalanceTooltip(
          (value) => this.formattedNumber(Math.abs(value), 'tooltip', useKilo),
          this.sourceLabelValue,
          this.usageLabelValue,
        );
      }

      tooltip.enabled = false;
      tooltip.external = (context) =>
        this.powerBalanceTooltip?.render(
          context,
          flags.sourceIds,
          flags.usageIds,
          flags.orderMap,
        );
      return;
    }

    if (this.powerBalanceTooltip) {
      this.powerBalanceTooltip.destroy();
      this.powerBalanceTooltip = undefined;
    }
  }

  private configureTooltipCallbacks(
    tooltip: TooltipConfig,
    data: ChartData,
    flags: {
      isPowerSplitterStack: boolean;
      isInverterStack: boolean;
      isHeatingStack: boolean;
    },
  ): void {
    tooltip.callbacks = {
      title: (tooltipItems) => this.buildTooltipTitle(tooltipItems),
      label: (tooltipItem) => this.buildTooltipLabel(tooltipItem, data, flags),
      footer: (tooltipItems) =>
        this.buildTooltipFooter(tooltipItems, data, flags),
    };
  }

  private buildTooltipTitle(
    tooltipItems: TooltipItem<ChartType>[],
  ): string | undefined {
    if (!tooltipItems.length) return;

    const dataset = tooltipItems[0].dataset as DatasetWithId;
    if (dataset.tooltipFields?.length) {
      const rawData = tooltipItems[0].raw as Record<string, unknown>;
      const timestamp = rawData.timestamp;

      if (typeof timestamp === 'number') {
        const date = new Date(timestamp);
        if (dataset.showTime) {
          const timeFormat = new Intl.DateTimeFormat(this.locale, {
            hour: '2-digit',
            minute: '2-digit',
          });
          const endDate = new Date(timestamp + 3600000);
          return `${timeFormat.format(date)} – ${timeFormat.format(endDate)}`;
        }
        return new Intl.DateTimeFormat(this.locale, {
          day: '2-digit',
          month: '2-digit',
          year: 'numeric',
        }).format(date);
      }

      return;
    }

    return;
  }

  private buildTooltipLabel(
    tooltipItem: TooltipItem<ChartType>,
    data: ChartData,
    flags: {
      isPowerSplitterStack: boolean;
      isHeatingStack: boolean;
    },
  ): string | string[] {
    const dataset = tooltipItem.dataset as DatasetWithId;
    const tooltipFields = dataset.tooltipFields;

    if (tooltipFields?.length) {
      const rawData = tooltipItem.raw as Record<string, unknown>;
      const lines: string[] = [];

      for (const field of tooltipFields) {
        let value: number | null = null;

        if (field.source === 'x') {
          value = tooltipItem.parsed.x ?? null;
        } else if (field.source === 'y') {
          value = tooltipItem.parsed.y ?? null;
        } else if (field.source === 'data' && field.dataKey) {
          const rawValue = rawData[field.dataKey];
          value = typeof rawValue === 'number' ? rawValue : null;
        }

        if (value === null) continue;

        if (field.transform === 'divideBy1000') value /= 1000;

        const formattedValue = new Intl.NumberFormat(this.locale, {
          minimumFractionDigits: 1,
          maximumFractionDigits: 1,
        }).format(value);

        const unitStr = field.unit ? ` ${field.unit}` : '';
        lines.push(`${field.name}: ${formattedValue}${unitStr}`);
      }

      return lines;
    }

    const datasetId = dataset.id;
    const { isPowerSplitterStack, isHeatingStack } = flags;

    if (isPowerSplitterStack && !tooltipItem.dataset.stack) return '';

    const label =
      data.datasets.length > 1 ? `${tooltipItem.dataset.label} ` : '';

    if (tooltipItem.parsed._custom) {
      return (
        label +
        this.formattedInterval(
          tooltipItem.parsed._custom.min,
          tooltipItem.parsed._custom.max,
        )
      );
    }

    const isStackedItem =
      (isPowerSplitterStack || isHeatingStack) && tooltipItem.dataset.stack;

    if (isStackedItem) {
      const showPercentages =
        isPowerSplitterStack || (isHeatingStack && data.datasets.length === 3);

      if (showPercentages) {
        const sum = data.datasets
          .filter((ds) => ds.stack === tooltipItem.dataset.stack)
          .reduce((acc, ds) => {
            const value = ds.data[tooltipItem.dataIndex] as number;
            return acc + (value || 0);
          }, 0);

        if (sum && tooltipItem.parsed.y) {
          return `${label}${((tooltipItem.parsed.y * 100) / sum).toFixed(0)} %`;
        }
      }
    }

    const isTemperature = datasetId?.includes('_temp');

    if (isTemperature) {
      const value = tooltipItem.parsed.y!;
      const formattedValue = new Intl.NumberFormat(this.locale, {
        minimumFractionDigits: 1,
        maximumFractionDigits: 1,
      }).format(value);
      return `${label}${formattedValue} °C`;
    }

    return label + this.formattedNumber(tooltipItem.parsed.y!);
  }

  private buildTooltipFooter(
    tooltipItems: TooltipItem<ChartType>[],
    data: ChartData,
    flags: {
      isPowerSplitterStack: boolean;
      isInverterStack: boolean;
      isHeatingStack: boolean;
    },
  ): string | undefined {
    if (!tooltipItems.length) return;

    const dataIndex = tooltipItems[0].dataIndex;

    if (flags.isPowerSplitterStack) {
      const totalDataset = data.datasets.find((ds) => !ds.stack);
      const sum = totalDataset?.data?.[dataIndex] as number | undefined;
      if (sum) return this.formattedNumber(sum);
    }

    if (
      (flags.isInverterStack || flags.isHeatingStack) &&
      tooltipItems.length > 1
    ) {
      const sum = tooltipItems.reduce((acc, item) => {
        if (item.dataset.stack && item.parsed.y) acc += item.parsed.y;
        return acc;
      }, 0);
      if (sum) return this.formattedNumber(sum);
    }
  }

  private getCssVar(name: string): string {
    return window
      .getComputedStyle(document.documentElement)
      .getPropertyValue(name)
      .trim();
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
    autoKilo: boolean = true,
  ) {
    const minValue = this.chart?.scales.y.min ?? this.minValue;
    const maxValue = this.chart?.scales.y.max ?? this.maxValue;

    let unitValuePrefix = '';

    // Don't scale euro values
    const isEuro = this.unitValue.includes('€');

    const kilo =
      autoKilo &&
      !isEuro &&
      (target === 'axis'
        ? maxValue > 1000 || minValue < -1000
        : number > 1000 || number < -1000);
    if (kilo) {
      number /= 1000.0;
      unitValuePrefix = 'k';
    }

    const { minDecimals, maxDecimals } = this.getDecimalPlaces(
      target,
      kilo,
      isEuro,
      minValue,
      maxValue,
    );

    const numberAsString = new Intl.NumberFormat(this.locale, {
      minimumFractionDigits: minDecimals,
      maximumFractionDigits: maxDecimals,
    }).format(number);

    return `${numberAsString} ${unitValuePrefix}${this.unitValue}`;
  }

  private getDecimalPlaces(
    target: 'axis' | 'tooltip',
    kilo: boolean,
    isEuro: boolean,
    minValue: number,
    maxValue: number,
  ): { minDecimals: number; maxDecimals: number } {
    if (kilo) {
      // For gram values (CO2 reduction), use only 1 decimal place even in tooltips
      const isGram = this.unitValue === 'g';
      // On axis: single decimal; on tooltip: precise (3) unless grams (1)
      const maxDecimals = target === 'axis' ? 1 : isGram ? 1 : 3;
      return { minDecimals: 0, maxDecimals };
    }

    if (isEuro) {
      // For Euro values:
      // - Axis: only show decimals if max < 10€ (keeps axis labels simple)
      // - Tooltips: show decimals if there are any small values (scaleMin < 10 && scaleMax < 100)
      const showDecimals =
        target === 'axis' ? maxValue < 10 : minValue < 10 && maxValue < 100;
      const decimals = showDecimals ? 2 : 0;
      return { minDecimals: decimals, maxDecimals: decimals };
    }

    // Without kilo, default to integers, unless unit is empty (dimensionless like COP) or °C
    const maxDecimals =
      this.unitValue === '' || this.unitValue === '°C' ? 1 : 0;
    return { minDecimals: 0, maxDecimals };
  }

  private formattedInterval(min: number, max: number) {
    const formattedMin = this.formattedNumber(min);
    const formattedMax = this.formattedNumber(max);

    return formattedMin === formattedMax
      ? formattedMin
      : `${formattedMin} - ${formattedMax}`;
  }

  private getPowerBalanceConfig(data: ChartData) {
    const sourceIds = new Set([
      'inverter_power',
      'battery_discharging_power',
      'grid_import_power',
    ]);

    const usageIds = new Set([
      'house_power',
      'heatpump_power',
      'wallbox_power',
      'battery_charging_power',
      'grid_export_power',
    ]);

    const stacks = new Set(['source', 'usage', 'combined']);
    const hasStack = data.datasets.some((dataset) =>
      stacks.has(dataset.stack ?? ''),
    );

    const hasSources = data.datasets.some((dataset) =>
      sourceIds.has((dataset as DatasetWithId).id ?? ''),
    );

    const hasUsage = data.datasets.some((dataset) =>
      usageIds.has((dataset as DatasetWithId).id ?? ''),
    );

    const orderMap = new Map(
      data.datasets.map((dataset, index) => [
        (dataset as DatasetWithId).id ?? '',
        index,
      ]),
    );

    return {
      sourceIds,
      usageIds,
      orderMap,
      isPowerBalance: hasStack && hasSources && hasUsage,
    };
  }

  // Extract numeric value from various data formats (number, array, or scatter point object)
  private extractNumericValue(
    value: unknown,
    mode: 'max' | 'min',
  ): number | null {
    if (typeof value === 'number') return value;
    if (Array.isArray(value))
      return mode === 'max' ? Math.max(...value) : Math.min(...value);
    // Handle scatter chart data points (objects with x/y properties)
    if (value && typeof value === 'object' && 'y' in value) {
      const y = (value as { y: unknown }).y;
      if (typeof y === 'number') return y;
    }
    return null;
  }

  // Get maximum value of all datasets, summing only positive values per stack
  private maxOf(data: ChartData) {
    const stackSums: Record<string, number[]> = {};
    let maxSum = 0;

    for (const dataset of data.datasets) {
      const stackKey = dataset.stack ?? '__default'; // Fallback for not stacked datasets
      if (dataset.data) {
        for (let index = 0; index < dataset.data.length; index++) {
          const value = dataset.data[index];
          const num = this.extractNumericValue(value, 'max');

          if (num !== null && num > 0) {
            stackSums[stackKey] ??= [];
            stackSums[stackKey][index] =
              (stackSums[stackKey][index] ?? 0) + num;
            maxSum = Math.max(maxSum, stackSums[stackKey][index]);
          }
        }
      }
    }

    return Math.ceil(maxSum);
  }

  // Get minimum value of all datasets, summing only negative values per stack
  private minOf(data: ChartData) {
    const stackSums: Record<string, number[]> = {};
    let minSum = 0;

    for (const dataset of data.datasets) {
      const stackKey = dataset.stack ?? '__default'; // Fallback for not stacked datasets
      if (dataset.data) {
        for (let index = 0; index < dataset.data.length; index++) {
          const value = dataset.data[index];
          const num = this.extractNumericValue(value, 'min');

          if (num !== null && num < 0) {
            stackSums[stackKey] ??= [];
            stackSums[stackKey][index] =
              (stackSums[stackKey][index] ?? 0) + num;
            minSum = Math.min(minSum, stackSums[stackKey][index]);
          }
        }
      }
    }

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

  private handleDblClick() {
    this.chart?.resetZoom();
  }

  private handleTouchOrClick(dataIndex: number, action: () => void) {
    if (isTouchEnabled()) {
      // To avoid conflict with tooltip, we wait for a second click
      if (this.lastTouchedIndex === dataIndex) {
        action();
        this.lastTouchedIndex = null;
      } else {
        this.lastTouchedIndex = dataIndex;
      }
    } else {
      action();
    }
  }

  private navigateToDrilldown(timestamp: number) {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');

    // Bar/line chart: Navigate based on current URL pattern
    const currentUrl = window.location.href;
    const drilldownLevels: Array<{ regex: RegExp; format: () => string }> = [
      { regex: /(\/all)$/, format: () => `${year}` }, // All → Year
      { regex: /(\/\d{4}|\/year)$/, format: () => `${year}-${month}` }, // Year → Month
      {
        regex: /(\/\d{4}-\d{2}|\/month)$/,
        format: () => `${year}-${month}-${day}`,
      }, // Month → Day
      {
        regex: /(\/\d{4}-W\d{2}|\/week)$/,
        format: () => `${year}-${month}-${day}`,
      }, // Week → Day
      {
        regex: /(\/\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2})$/,
        format: () => `${year}-${month}-${day}`,
      }, // Range → Day
      { regex: /(\/P\d{1,3}D)$/, format: () => `${year}-${month}-${day}` }, // Days → Day
      { regex: /(\/P\d{1,2}M)$/, format: () => `${year}-${month}` }, // Months → Month
      { regex: /(\/P\d{1,2}Y)$/, format: () => `${year}` }, // Years → Year
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

    // No matching drilldown pattern found - this is OK for charts without drilldown
  }
}

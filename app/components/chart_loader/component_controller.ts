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
  ChartEvent,
  ActiveElement,
  Plugin,
} from 'chart.js';

import 'chartjs-adapter-luxon';
import zoomPlugin from 'chartjs-plugin-zoom';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

import { buildCustomXAxisPlugin } from '@/utils/chartPluginCustomXAxis';

// Axes & styling
import {
  applyAxisStyles,
  applyXAxisTemperatureFormatter,
  applyYAxisTickFormatter,
  applyYAxisZeroLine,
  applyY1TemperatureFormatter,
  applyZeroLineHighlight,
  getAxisColors,
} from './helpers';

// Options & tooltip setup
import {
  applyCrosshairFix,
  applyFixedYAxisWidth,
  applyLocaleToTimeScale,
  applyTooltipTheme,
  configureChartTooltip,
  ensureFixedBottomTooltipPositioner,
  configurePowerBalanceTooltip,
  createTouchIndexState,
  getPowerBalanceFlags,
  handleDoubleClickReset,
} from './helpers';

// Interactions
import {
  buildDrilldownUrl,
  handleChartClick,
  handleHoverCursor,
  handleTouchOrClick,
} from './helpers';

// Tooltips
import {
  buildTooltipCallbacks,
  GenericChartTooltip,
  PowerBalanceTooltip,
} from './helpers';

// Data & formatting
import {
  ColorManager,
  extractNumericValue,
  formatNumber,
  isOverlapping,
  maxOf,
  minOf,
} from './helpers';
import type { TimeScaleOptions, TooltipConfig } from './helpers';

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
ensureFixedBottomTooltipPositioner(-14);

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
  private readonly colorManager = new ColorManager((datasets) =>
    isOverlapping(datasets),
  );
  private animationTimeout?: ReturnType<typeof setTimeout>;

  private maxValue: number = 0;
  private minValue: number = 0;
  private locale: string = 'en';
  private lastTouchedIndex: number | null = null;
  private powerBalanceTooltip?: PowerBalanceTooltip;
  private genericTooltip?: GenericChartTooltip;

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

    this.genericTooltip?.destroy();
    this.genericTooltip = undefined;
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
    applyLocaleToTimeScale(options.scales.x as TimeScaleOptions, this.locale);

    this.maxValue = maxOf(data);
    this.minValue = minOf(data);

    const axisColors = getAxisColors(this.getCssVar.bind(this));
    applyAxisStyles(options, axisColors);
    applyFixedYAxisWidth(options);
    applyTooltipTheme(options, this.getCssVar.bind(this));

    applyYAxisTickFormatter(options, (value, target) =>
      this.formattedNumber(value, target),
    );
    applyXAxisTemperatureFormatter(options);
    applyZeroLineHighlight(options, axisColors);
    applyY1TemperatureFormatter(options);
    applyYAxisZeroLine(options, axisColors, this.minValue);

    options.onClick = (
      _event: ChartEvent,
      elements: ActiveElement[],
      chart: Chart,
    ) => {
      handleChartClick(
        elements,
        chart,
        (path) =>
          handleTouchOrClick(
            isTouchEnabled,
            this.touchIndexState(),
            elements[0].index,
            () => Turbo.visit(path),
          ),
        (timestamp) =>
          handleTouchOrClick(
            isTouchEnabled,
            this.touchIndexState(),
            elements[0].index,
            () => this.navigateToDrilldown(timestamp),
          ),
      );
    };

    options.onHover = (
      event: ChartEvent,
      elements: ActiveElement[],
      chart: Chart,
    ) => handleHoverCursor(event, elements, chart);

    configureChartTooltip(options, data, {
      getTooltipFlags: getPowerBalanceFlags,
      configurePowerBalanceTooltip:
        this.configurePowerBalanceTooltip.bind(this),
      configureGenericTooltip: this.configureGenericTooltip.bind(this),
      configureTooltipCallbacks: this.configureTooltipCallbacks.bind(this),
    });

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

  private configurePowerBalanceTooltip(
    tooltip: TooltipConfig,
    flags: {
      isPowerBalance: boolean;
      sourceIds: Set<string>;
      usageIds: Set<string>;
      orderMap: Map<string, number>;
    },
  ): void {
    configurePowerBalanceTooltip(tooltip, flags, {
      getTooltip: () => this.powerBalanceTooltip,
      setTooltip: (tooltipInstance) => {
        this.powerBalanceTooltip = tooltipInstance;
      },
      buildTooltip: () => {
        const useKilo = this.typeValue !== 'line';
        return new PowerBalanceTooltip(
          (value) => this.formattedNumber(Math.abs(value), 'tooltip', useKilo),
          this.sourceLabelValue,
          this.usageLabelValue,
        );
      },
    });
  }

  private configureGenericTooltip(tooltip: TooltipConfig): void {
    if (!this.genericTooltip) {
      this.genericTooltip = new GenericChartTooltip();
    }

    tooltip.enabled = false;
    tooltip.external = (context) => this.genericTooltip?.render(context);
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
    tooltip.callbacks = buildTooltipCallbacks(
      {
        locale: this.locale,
        formattedNumber: (value) => this.formattedNumber(value),
        extractNumericValue,
      },
      data,
      flags,
    );
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
    return formatNumber(number, {
      target,
      autoKilo,
      unitValue: this.unitValue,
      locale: this.locale,
      minValue,
      maxValue,
    });
  }

  private handleDblClick() {
    handleDoubleClickReset(this.chart);
  }

  private touchIndexState() {
    return createTouchIndexState(
      () => this.lastTouchedIndex,
      (value) => {
        this.lastTouchedIndex = value;
      },
    );
  }

  private navigateToDrilldown(timestamp: number) {
    const newUrl = buildDrilldownUrl(window.location.href, timestamp);
    if (newUrl) Turbo.visit(newUrl);
  }
}

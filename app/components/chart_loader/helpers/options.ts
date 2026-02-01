// Helpers for chart options and tooltip configuration.
import type { ChartData, ChartOptions, ChartType, TooltipItem } from 'chart.js';

import type { DatasetWithId } from './types';
import type { TimeScaleOptions } from './types';

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object';

// Applies locale to the time scale date adapter when present.
export const applyLocaleToTimeScale = (
  xScale: TimeScaleOptions,
  locale: string,
): void => {
  if (xScale.adapters?.date) {
    xScale.adapters.date.locale = locale;
  }
};

// Forces a fixed Y-axis width if configured on the scale options.
export const applyFixedYAxisWidth = (options: ChartOptions): void => {
  const fixedYAxisWidth = (options.scales?.y as Record<string, unknown>)
    ?.fixedWidth;
  if (typeof fixedYAxisWidth !== 'number' || !Number.isFinite(fixedYAxisWidth))
    return;

  options.scales!.y!.afterFit = (axis) => {
    axis.width = fixedYAxisWidth;
  };
};

// Applies tooltip colors from CSS variables.
export const applyTooltipTheme = (
  options: ChartOptions,
  getCssVar: (name: string) => string,
): void => {
  const tooltip = options.plugins?.tooltip;
  if (!isRecord(tooltip)) return;

  const tooltipText = getCssVar('--chart-tooltip-text');
  tooltip.backgroundColor = getCssVar('--chart-tooltip-bg');
  tooltip.titleColor = tooltipText;
  tooltip.bodyColor = tooltipText;
  tooltip.footerColor = tooltipText;
  tooltip.borderColor = getCssVar('--chart-tooltip-border');
  tooltip.borderWidth = 1;
};

// Configures tooltip filtering, ordering, and external handlers.
export const configureChartTooltip = (
  options: ChartOptions,
  data: ChartData,
  handlers: {
    getTooltipFlags: (data: ChartData) => {
      isPowerBalance: boolean;
      sourceIds: Set<string>;
      usageIds: Set<string>;
      orderMap: Map<string, number>;
      isPowerSplitterStack: boolean;
      isInverterStack: boolean;
      isHeatingStack: boolean;
    };
    configurePowerBalanceTooltip: (
      tooltip: NonNullable<NonNullable<ChartOptions['plugins']>['tooltip']>,
      flags: {
        isPowerBalance: boolean;
        sourceIds: Set<string>;
        usageIds: Set<string>;
        orderMap: Map<string, number>;
      },
    ) => void;
    configureTooltipCallbacks: (
      tooltip: NonNullable<NonNullable<ChartOptions['plugins']>['tooltip']>,
      data: ChartData,
      flags: {
        isPowerSplitterStack: boolean;
        isInverterStack: boolean;
        isHeatingStack: boolean;
      },
    ) => void;
  },
): void => {
  const tooltip = options.plugins?.tooltip;
  if (!tooltip) return;

  const getTimestamp = (tooltipItem: TooltipItem<ChartType>): number | null => {
    const parsedX = tooltipItem.parsed?.x;
    if (typeof parsedX === 'number') return parsedX;

    const chart = (tooltipItem as { chart?: { data?: { labels?: unknown[] } } })
      .chart;
    const label = chart?.data?.labels?.[tooltipItem.dataIndex];
    return typeof label === 'number' ? label : null;
  };

  const hasValues = (tooltipItem: TooltipItem<ChartType>): boolean => {
    if (Array.isArray(tooltipItem.raw))
      return tooltipItem.raw.filter((value) => value !== null).length > 0;
    return tooltipItem.raw !== null;
  };

  const isPastOrFuture = (
    datasetId: string | undefined,
    timestamp: number,
  ): boolean => {
    const now = Date.now();
    if (datasetId === 'inverter_power_forecast') return timestamp <= now;
    if (datasetId === 'inverter_power') return timestamp > now;
    return false;
  };

  tooltip.filter = (tooltipItem: TooltipItem<ChartType>): boolean => {
    const dataset = tooltipItem.dataset as DatasetWithId;
    if (dataset.tooltip === false) return false;

    if (
      dataset.id === 'inverter_power_forecast' ||
      dataset.id === 'inverter_power'
    ) {
      const timestamp = getTimestamp(tooltipItem);
      if (timestamp !== null && isPastOrFuture(dataset.id, timestamp))
        return false;
    }

    return hasValues(tooltipItem);
  };

  const flags = handlers.getTooltipFlags(data);

  tooltip.footerFont = { size: 20 };

  if (!flags.isPowerBalance) {
    tooltip.itemSort = (a, b) => b.datasetIndex - a.datasetIndex;
  }

  handlers.configurePowerBalanceTooltip(tooltip, flags);
  handlers.configureTooltipCallbacks(tooltip, data, flags);
};

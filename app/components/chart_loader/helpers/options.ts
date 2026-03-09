// Helpers for chart options and tooltip configuration.
import type { ChartData, ChartOptions, ChartType, TooltipItem } from 'chart.js';

import type { PowerBalanceFlags } from './power_balance';
import type { DatasetWithId, TimeScaleOptions, TooltipConfig } from './types';

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
    const widthScale = document.fullscreenElement ? 1.2 : 1;
    axis.width = Math.round(fixedYAxisWidth * widthScale);
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
    getTooltipFlags: (data: ChartData) => PowerBalanceFlags;
    configurePowerBalanceTooltip: (
      tooltip: TooltipConfig,
      flags: PowerBalanceFlags,
    ) => void;
    configureGenericTooltip: (tooltip: TooltipConfig) => void;
    configureTooltipCallbacks: (
      tooltip: TooltipConfig,
      data: ChartData,
      flags: PowerBalanceFlags,
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

  const isFutureActual = (
    datasetId: string | undefined,
    timestamp: number,
  ): boolean => {
    if (datasetId === 'inverter_power') return timestamp > Date.now();
    return false;
  };

  tooltip.filter = (tooltipItem: TooltipItem<ChartType>): boolean => {
    const dataset = tooltipItem.dataset as DatasetWithId;
    if (dataset.tooltip === false) return false;

    if (dataset.id === 'inverter_power') {
      const timestamp = getTimestamp(tooltipItem);
      if (timestamp !== null && isFutureActual(dataset.id, timestamp))
        return false;
    }

    return hasValues(tooltipItem);
  };

  const flags = handlers.getTooltipFlags(data);

  tooltip.footerFont = { size: 20 };

  // Show color swatches when multiple datasets are visible in tooltips
  const tooltipDatasets = data.datasets.filter(
    (ds) => (ds as DatasetWithId).tooltip !== false,
  );
  if (tooltipDatasets.length > 1) {
    tooltip.displayColors = true;
  }

  if (!flags.isPowerBalance) {
    tooltip.itemSort = (a, b) => b.datasetIndex - a.datasetIndex;
  }

  handlers.configurePowerBalanceTooltip(tooltip, flags);

  if (!flags.isPowerBalance) {
    handlers.configureGenericTooltip(tooltip);
  }

  handlers.configureTooltipCallbacks(tooltip, data, flags);
};

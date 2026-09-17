// Builds tooltip callbacks (title/label/footer/labelColor) based on data and stacks.

import type { ChartData, ChartType, Color, TooltipItem } from 'chart.js';
import { dateTimeFormatter, numberFormatter } from './formatting';
import { isTemperatureDataset, tooltipRange } from './tooltip_range';
import type { DatasetWithId, Range } from './types';

type TooltipFlags = {
  isPowerSplitterStack: boolean;
  isInverterStack: boolean;
  isHeatingStack: boolean;
  isTotalConsumptionStack: boolean;
};

const HEATPUMP_COSTS_STACK = 'HeatpumpCosts';

type TooltipHelpers = {
  locale: string;
  formattedNumber: (value: number, range?: Range) => string;
  extractNumericValue: (value: unknown, mode: 'max' | 'min') => number | null;
};

// Builds Chart.js tooltip callbacks (title/label/footer).
export const buildTooltipCallbacks = (
  helpers: TooltipHelpers,
  data: ChartData,
  flags: TooltipFlags,
): {
  title: (tooltipItems: TooltipItem<ChartType>[]) => string | undefined;
  label: (tooltipItem: TooltipItem<ChartType>) => string | string[];
  labelColor: (
    tooltipItem: TooltipItem<ChartType>,
  ) => { backgroundColor: Color; borderColor: Color } | undefined;
  footer: (tooltipItems: TooltipItem<ChartType>[]) => string | undefined;
} => {
  const { locale, formattedNumber, extractNumericValue } = helpers;

  const tooltipValue = (tooltipItem: TooltipItem<ChartType>): number | null => {
    const parsedY = tooltipItem.parsed?.y;
    if (typeof parsedY === 'number') return parsedY;

    return extractNumericValue(tooltipItem.raw, 'max');
  };

  return {
    title: (tooltipItems) => {
      if (!tooltipItems.length) return;

      const dataset = tooltipItems[0].dataset as DatasetWithId;
      if (!dataset.tooltipFields?.length) return;

      const rawData = tooltipItems[0].raw as Record<string, unknown>;
      const timestamp = rawData.timestamp;
      if (typeof timestamp !== 'number') return;

      const date = new Date(timestamp);
      if (dataset.showTime) {
        const timeFormat = dateTimeFormatter(locale, 'time');
        const endDate = new Date(timestamp + 3600000);
        return `${timeFormat.format(date)} – ${timeFormat.format(endDate)}`;
      }

      return dateTimeFormatter(locale, 'date').format(date);
    },

    label: (tooltipItem) => {
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

          const formattedValue = numberFormatter(locale, 1, 1).format(value);

          const unitStr = field.unit ? ` ${field.unit}` : '';
          lines.push(`${field.name}: ${formattedValue}${unitStr}`);
        }

        return lines;
      }

      const { isPowerSplitterStack, isHeatingStack } = flags;

      if (isPowerSplitterStack && !tooltipItem.dataset.stack) return '';

      // Every line of one tooltip reads the range of the same render, so they
      // keep one unit.
      const range = tooltipRange(tooltipItem.chart.tooltip?.dataPoints);

      // Show label prefix when multiple datasets are displayed in tooltip
      const tooltipDatasets = data.datasets.filter(
        (ds) => (ds as DatasetWithId).tooltip !== false,
      );
      const label =
        tooltipDatasets.length > 1 ? `${tooltipItem.dataset.label}: ` : '';

      // Charts that negate a series for opposite-direction bars (e.g. battery
      // discharge, grid import) carry the direction in the label already, so
      // show the magnitude without the redundant minus sign.
      const rawValue = tooltipValue(tooltipItem);
      const parsedValue =
        dataset.tooltipAbs && rawValue !== null ? Math.abs(rawValue) : rawValue;

      if (tooltipItem.parsed._custom) {
        if (parsedValue !== null)
          return label + formattedNumber(parsedValue, range);
        const fallback =
          tooltipItem.parsed._custom.max ?? tooltipItem.parsed._custom.min;
        return label + formattedNumber(fallback, range);
      }

      if (
        isHeatingStack &&
        tooltipItem.dataset.stack &&
        data.datasets.length === 3
      ) {
        const sum = data.datasets
          .filter((ds) => ds.stack === tooltipItem.dataset.stack)
          .reduce((acc, ds) => {
            const value = ds.data[tooltipItem.dataIndex] as number;
            return acc + (value || 0);
          }, 0);

        if (sum && tooltipItem.parsed.y != null) {
          return `${label}${((tooltipItem.parsed.y * 100) / sum).toFixed(0)} %`;
        }
      }

      // A temperature prints its own unit instead of the chart's, which may be
      // watts. The tenth belongs to how a temperature reads, so it stays even
      // for a whole degree.
      if (isTemperatureDataset(dataset)) {
        const formattedValue = numberFormatter(locale, 1, 1).format(
          parsedValue ?? 0,
        );
        return `${label}${formattedValue} °C`;
      }

      if (parsedValue !== null) {
        return label + formattedNumber(parsedValue, range);
      }

      const fallbackY = tooltipItem.parsed.y!;
      return (
        label +
        formattedNumber(
          dataset.tooltipAbs ? Math.abs(fallbackY) : fallbackY,
          range,
        )
      );
    },

    // Return the solid resolved color for tooltip color swatches.
    // Without this, gradient datasets produce CanvasGradient objects
    // that render as transparent in the custom HTML tooltip.
    labelColor: (tooltipItem) => {
      const dataset = tooltipItem.dataset as DatasetWithId;
      const color = dataset.tooltipColor;
      if (color) return { backgroundColor: color, borderColor: color };
    },

    footer: (tooltipItems) => {
      if (!tooltipItems.length) return;

      const dataIndex = tooltipItems[0].dataIndex;
      const range = tooltipRange(tooltipItems);

      if (flags.isPowerSplitterStack) {
        const totalDataset = data.datasets.find((ds) => !ds.stack);
        const sum = totalDataset?.data?.[dataIndex] as number | undefined;
        if (sum) return formattedNumber(sum, range);
      }

      if (
        (flags.isInverterStack ||
          flags.isHeatingStack ||
          flags.isTotalConsumptionStack) &&
        tooltipItems.length > 1
      ) {
        const sum = tooltipItems.reduce((acc, item) => {
          if (item.dataset.stack && item.parsed.y) acc += item.parsed.y;
          return acc;
        }, 0);

        if (sum) return formattedNumber(sum, range);
      }

      const heatpumpCostsItems = tooltipItems.filter(
        (item) => item.dataset.stack === HEATPUMP_COSTS_STACK,
      );
      if (heatpumpCostsItems.length > 1) {
        const sum = heatpumpCostsItems.reduce((acc, item) => {
          if (typeof item.parsed.y === 'number') return acc + item.parsed.y;
          return acc;
        }, 0);

        if (sum) return formattedNumber(sum, range);
      }
    },
  };
};

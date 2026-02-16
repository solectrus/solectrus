// Builds tooltip callbacks (title/label/footer/labelColor) based on data and stacks.

import type { ChartData, ChartType, Color, TooltipItem } from 'chart.js';
import type { DatasetWithId } from './types';

type TooltipFlags = {
  isPowerSplitterStack: boolean;
  isInverterStack: boolean;
  isHeatingStack: boolean;
};

type TooltipHelpers = {
  locale: string;
  formattedNumber: (value: number) => string;
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
        const timeFormat = new Intl.DateTimeFormat(locale, {
          hour: '2-digit',
          minute: '2-digit',
        });
        const endDate = new Date(timestamp + 3600000);
        return `${timeFormat.format(date)} – ${timeFormat.format(endDate)}`;
      }

      return new Intl.DateTimeFormat(locale, {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      }).format(date);
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

          const formattedValue = new Intl.NumberFormat(locale, {
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

      // Show label prefix when multiple datasets are displayed in tooltip
      const tooltipDatasets = data.datasets.filter(
        (ds) => (ds as DatasetWithId).tooltip !== false,
      );
      const label =
        tooltipDatasets.length > 1 ? `${tooltipItem.dataset.label}: ` : '';

      const parsedValue = tooltipValue(tooltipItem);

      if (tooltipItem.parsed._custom) {
        if (parsedValue !== null) return label + formattedNumber(parsedValue);
        const fallback =
          tooltipItem.parsed._custom.max ?? tooltipItem.parsed._custom.min;
        return label + formattedNumber(fallback);
      }

      const isStackedItem =
        (isPowerSplitterStack || isHeatingStack) && tooltipItem.dataset.stack;

      if (isStackedItem) {
        const showPercentages =
          isPowerSplitterStack ||
          (isHeatingStack && data.datasets.length === 3);

        if (showPercentages) {
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
      }

      const isTemperature = datasetId?.includes('_temp');

      if (isTemperature) {
        const value = parsedValue ?? 0;
        const formattedValue = new Intl.NumberFormat(locale, {
          minimumFractionDigits: 1,
          maximumFractionDigits: 1,
        }).format(value);
        return `${label}${formattedValue} °C`;
      }

      if (datasetId === 'inverter_power_forecast') {
        const value = parsedValue ?? 0;
        const formattedValue = new Intl.NumberFormat(locale, {
          minimumFractionDigits: 0,
          maximumFractionDigits: 0,
        }).format(value);
        return `${label}${formattedValue} W`;
      }

      if (parsedValue !== null) {
        return label + formattedNumber(parsedValue);
      }

      return label + formattedNumber(tooltipItem.parsed.y!);
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

      if (flags.isPowerSplitterStack) {
        const totalDataset = data.datasets.find((ds) => !ds.stack);
        const sum = totalDataset?.data?.[dataIndex] as number | undefined;
        if (sum) return formattedNumber(sum);
      }

      if (
        (flags.isInverterStack || flags.isHeatingStack) &&
        tooltipItems.length > 1
      ) {
        const sum = tooltipItems.reduce((acc, item) => {
          if (item.dataset.stack && item.parsed.y) acc += item.parsed.y;
          return acc;
        }, 0);

        if (sum) return formattedNumber(sum);
      }
    },
  };
};

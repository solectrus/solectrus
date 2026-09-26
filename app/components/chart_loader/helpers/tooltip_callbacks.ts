// Builds tooltip callbacks (title/label/footer/labelColor) based on data and stacks.

import type { ChartData, ChartType, Color, TooltipItem } from 'chart.js';
import { roundedParts, roundedSum } from '@/utils/roundedParts';

import {
  dateTimeFormatter,
  formatInterval,
  numberFormatter,
} from './formatting';
import { isTemperatureDataset, tooltipRange } from './tooltip_range';
import { perRender } from './tooltip_utils';
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
  roundingDigits: (range?: Range) => number;
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
  const { locale, formattedNumber, roundingDigits, extractNumericValue } =
    helpers;

  const sumOf = (rows: TooltipItem<ChartType>[]) =>
    rows.reduce((acc, item) => acc + item.parsed.y!, 0);

  // The rows of one tooltip that its footer adds up, and their sum. A stack
  // of the power splitter takes its sum from the total dataset.
  const summedRows = (
    points: readonly TooltipItem<ChartType>[],
  ): { rows: TooltipItem<ChartType>[]; sum: number } | undefined => {
    if (flags.isPowerSplitterStack) {
      const totalDataset = data.datasets.find((ds) => !ds.stack);
      const sum = totalDataset?.data?.[points[0].dataIndex] as
        number | undefined;
      const rows = points.filter(
        (item) => item.dataset.stack && typeof item.parsed.y === 'number',
      );
      if (sum) return { rows, sum };
    }

    if (
      (flags.isInverterStack ||
        flags.isHeatingStack ||
        flags.isTotalConsumptionStack) &&
      points.length > 1
    ) {
      const rows = points.filter((item) => item.dataset.stack && item.parsed.y);
      const sum = sumOf(rows);
      if (sum) return { rows, sum };
    }

    const costs = points.filter(
      (item) => item.dataset.stack === HEATPUMP_COSTS_STACK,
    );
    if (costs.length > 1) {
      const rows = costs.filter((item) => typeof item.parsed.y === 'number');
      const sum = sumOf(rows);
      if (sum) return { rows, sum };
    }
  };

  // The rows and the footer of one tooltip read the same rounded values, so
  // they visibly add up. Without a sum to show, there is nothing.
  const roundedSumOf = perRender((points) => {
    const summed = summedRows(points);
    if (!summed) return;

    const { parts, sum } = roundedSum(
      summed.rows.map((item) => item.parsed.y!),
      summed.sum,
      roundingDigits(tooltipRange(points)),
    );

    return {
      rows: new Map(
        summed.rows.map((item, i) => [item.datasetIndex, parts[i]]),
      ),
      sum,
    };
  });

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
      const rawValue =
        roundedSumOf(tooltipItem.chart.tooltip?.dataPoints)?.rows.get(
          tooltipItem.datasetIndex,
        ) ?? tooltipValue(tooltipItem);
      const parsedValue =
        dataset.tooltipAbs && rawValue !== null ? Math.abs(rawValue) : rawValue;

      // A temperature prints its own unit instead of the chart's, which may be
      // watts. The tenth belongs to how a temperature reads, so it stays even
      // for a whole degree.
      const formattedValue = (value: number) =>
        isTemperatureDataset(dataset)
          ? `${numberFormatter(locale, 1, 1).format(value)} °C`
          : formattedNumber(value, range);

      // A min/max bar shows both ends
      if (tooltipItem.parsed._custom) {
        const { min, max } = tooltipItem.parsed._custom;
        return label + formatInterval(min, max, formattedValue);
      }

      if (
        isHeatingStack &&
        tooltipItem.dataset.stack &&
        data.datasets.length === 3
      ) {
        const stack = data.datasets.filter(
          (ds) => ds.stack === tooltipItem.dataset.stack,
        );
        const values = stack.map(
          (ds) => (ds.data[tooltipItem.dataIndex] as number) || 0,
        );
        const sum = values.reduce((acc, value) => acc + value, 0);

        // Whole percentages that add up to 100
        if (sum && tooltipItem.parsed.y != null) {
          const percents = roundedParts(
            values.map((value) => (value * 100) / sum),
          );
          return `${label}${percents[stack.indexOf(tooltipItem.dataset)]} %`;
        }
      }

      if (parsedValue !== null || isTemperatureDataset(dataset))
        return label + formattedValue(parsedValue ?? 0);

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

      // A sum that rounds to 0 still shows, as "0 W"
      const rounded = roundedSumOf(tooltipItems);
      if (rounded)
        return formattedNumber(rounded.sum, tooltipRange(tooltipItems));
    },
  };
};

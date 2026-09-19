// Axis-specific formatting: tick callbacks, temperature labels, and zero-line styling.
import type { ChartOptions } from 'chart.js';

import type { ExtendedTickOptions } from './types';

type AxisColors = {
  grid: string;
  zeroLine: string;
};

// Applies number formatting to Y-axis tick labels, honoring the custom
// callback marker for absolute values.
export const applyYAxisTickFormatter = (
  options: ChartOptions,
  formattedNumber: (value: number, target?: 'axis' | 'tooltip') => string,
): void => {
  const yTicks = options.scales?.y?.ticks as ExtendedTickOptions | undefined;
  if (!yTicks) return;

  if (yTicks.callback === 'formatAbs') {
    options.scales!.y!.ticks!.callback = (value) =>
      typeof value === 'number'
        ? formattedNumber(Math.abs(value), 'axis')
        : value;
  } else if (typeof yTicks.callback !== 'function') {
    options.scales!.y!.ticks!.callback = (value) =>
      typeof value === 'number' ? formattedNumber(value, 'axis') : value;
  }
};

// Formats X-axis ticks as temperatures when the custom marker is set.
export const applyXAxisTemperatureFormatter = (options: ChartOptions): void => {
  const xTicks = options.scales?.x?.ticks as ExtendedTickOptions | undefined;
  if (xTicks?.callback === 'formatTemperature') {
    options.scales!.x!.ticks!.callback = (value) =>
      typeof value === 'number' ? `${value.toFixed(1)} °C` : value;
  }
};

// The two answers of the font callback below. Returned by identity, so a tick
// resolved on every layout does not allocate a fresh object each time.
const EMPHASIZED_FONT = { weight: 'bold' } as const;
const PLAIN_FONT = {} as const;

// Draws one X-axis label in bold, the one the chart named. A chart of twelve
// months carries no year on its axis, so the month we are in is told apart by
// its weight rather than by its place.
export const applyXAxisEmphasis = (options: ChartOptions): void => {
  const xTicks = options.scales?.x?.ticks as ExtendedTickOptions | undefined;
  const emphasized = xTicks?.emphasize;
  if (emphasized === undefined) return;

  options.scales!.x!.ticks!.font = (context) =>
    context.index === emphasized ? EMPHASIZED_FONT : PLAIN_FONT;
};

// Highlights the zero line on the X-axis grid when configured.
export const applyZeroLineHighlight = (
  options: ChartOptions,
  axisColors: AxisColors,
): void => {
  if (options.scales?.x?.grid?.color === 'zeroLineHighlight') {
    const { grid, zeroLine } = axisColors;
    options.scales.x.grid.color = (context) =>
      context.tick.value === 0 ? zeroLine : grid;
  }
};

// Formats Y1-axis ticks as temperatures.
export const applyY1TemperatureFormatter = (options: ChartOptions): void => {
  if (options.scales?.y1?.ticks) {
    options.scales.y1.ticks.callback = (value) =>
      typeof value === 'number' ? `${value} °C` : value;
  }
};

// Adds a zero-line grid highlight on Y when negative values exist.
export const applyYAxisZeroLine = (
  options: ChartOptions,
  axisColors: AxisColors,
  minValue: number,
): void => {
  if (minValue >= 0 || !options.scales?.y) return;

  const { grid, zeroLine } = axisColors;
  options.scales.y.grid = {
    color: (context) => (context.tick.value === 0 ? zeroLine : grid),
  };
};

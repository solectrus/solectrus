// Shared helper types and dataset extensions for chart helpers.
import type { ChartData, ChartDataset, ChartOptions } from 'chart.js';

export type TooltipField = {
  source: 'x' | 'y' | 'data';
  name: string;
  unit: string;
  dataKey?: string;
  transform?: 'divideBy1000';
};

export type DatasetWithId = ChartDataset & {
  id?: string;
  // The quantity the sensor measures, as its definition names it
  // ('watt', 'celsius', 'percent', 'money', ...), not a printable label.
  unit?: string;
  tooltip?: boolean;
  tooltipFields?: TooltipField[];
  showTime?: boolean;
  noGradient?: boolean;
  opacity?: number;
  colorClass?: string;
  colorScale?: ColorScaleStop[];
  opacities?: number[];
  hatchFill?: boolean;
  tooltipColor?: string;
  tooltipAbs?: boolean;
};

// A chart may state whether its fills cover each other instead of leaving that
// to isOverlapping, whose dataset-count heuristic misreads stacked fills.
export type ChartDataWithOverlap = ChartData & {
  overlapping?: boolean;
};

// The lowest and highest value of what is shown together: the axis for a
// tick, the lines of one tooltip for a tooltip.
export type Range = {
  min: number;
  max: number;
};

export type ColorScaleStop = {
  value: number;
  colorClass: string;
};

export type ResolvedColorScaleStop = {
  value: number;
  color: string;
};

// Allow segment colors on line datasets
export type LineDatasetWithSegment = ChartDataset<'line'> & {
  segment?: {
    borderColor: (ctx: { p0DataIndex: number }) => string;
  };
  opacity?: number;
};

// Extended scale options to include adapter configuration for time scales
export type TimeScaleOptions = {
  adapters?: {
    date?: {
      locale?: string;
    };
  };
};

// Resolved Chart.js tooltip configuration type
export type TooltipConfig = NonNullable<
  NonNullable<ChartOptions['plugins']>['tooltip']
>;

// Extended tick options with custom callback marker
export type ExtendedTickOptions = {
  callback?:
    ((value: number | string) => string) | 'formatTemperature' | 'formatAbs';
};

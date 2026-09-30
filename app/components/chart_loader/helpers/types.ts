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
  // Hatches the whole dataset, or with one entry for each data point only
  // the points that are true
  hatchFill?: boolean | boolean[];
  tooltipColor?: string;
  tooltipAbs?: boolean;
  // False when the tooltip title names the dataset already, so its rows leave
  // the label out.
  tooltipPrefix?: boolean;
  // The key of the dataset's list in `averages`.
  sensorName?: string;
};

// A chart may state whether its fills cover each other instead of leaving that
// to isOverlapping, whose dataset-count heuristic misreads stacked fills.
export type ChartDataWithOverlap = ChartData & {
  overlapping?: boolean;
};

// A chart of grouped bars may carry the average of each group, one value per
// label and null where it has none. One list per sensor, because a pair of
// opposite bars has an average above the zero line and one below it.
export type ChartDataWithAverages = ChartData & {
  averages?: Record<string, (number | null)[]>;
  averageLabel?: string;
};

// What a data point may carry beyond its coordinates. One type, so the shape
// the server writes is described in one place rather than guessed at each
// reader.
//
// `tooltipTitle`: the point names itself, for a chart whose axis label is
// abbreviated for want of room ("Sep" on the axis, "September 2024" in the
// tooltip).
export type ChartPointExtras = {
  tooltipTitle?: string;
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

// What a chart may state about its tooltip beyond the options Chart.js knows.
//
// `anchorToValues`: the tooltip sits at the height of the value it shows,
// instead of in the middle of the plot where it sits by default.
export type TooltipConfigExtras = TooltipConfig & {
  anchorToValues?: boolean;
};

// Extended tick options with custom callback marker, and the index of the one
// label a chart wants drawn in bold.
export type ExtendedTickOptions = {
  callback?:
    ((value: number | string) => string) | 'formatTemperature' | 'formatAbs';
  emphasize?: number;
};

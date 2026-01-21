import { ChartDataset } from 'chart.js';

export type TooltipField = {
  source: 'x' | 'y' | 'data';
  name: string;
  unit: string;
  dataKey?: string;
  transform?: 'divideBy1000';
};

export type DatasetWithId = ChartDataset & {
  id?: string;
  tooltipFields?: TooltipField[];
  showTime?: boolean;
  noGradient?: boolean;
  colorClass?: string;
  colorScale?: ColorScaleStop[];
  opacities?: number[];
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

// Extended tick options with custom callback marker
export type ExtendedTickOptions = {
  callback?:
    | ((value: number | string) => string)
    | 'formatTemperature'
    | 'formatAbs';
};

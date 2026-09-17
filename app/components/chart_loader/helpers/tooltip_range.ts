// The range that scales one tooltip, read from the values it shows.
import type { ChartType, TooltipItem } from 'chart.js';

import { extractNumericValue } from './data_extents';
import type { DatasetWithId, Range } from './types';

// A dataset whose id contains "_temp" carries a temperature in degrees
// Celsius, not the unit of the chart. The payload has no per-dataset unit, so
// the id is the only marker.
export const isTemperatureDataset = (dataset: DatasetWithId): boolean =>
  Boolean(dataset.id?.includes('_temp'));

const computeRange = (
  points: readonly TooltipItem<ChartType>[],
): Range | undefined => {
  const values = points
    .filter((point) => {
      const dataset = point.dataset as DatasetWithId;
      return !dataset.tooltipFields?.length && !isTemperatureDataset(dataset);
    })
    .flatMap((point) => [
      extractNumericValue(point.raw, 'min'),
      extractNumericValue(point.raw, 'max'),
    ])
    .filter((value) => value !== null);

  if (!values.length) return;

  return { min: Math.min(...values), max: Math.max(...values) };
};

// Chart.js builds a fresh dataPoints array for every tooltip render, so the
// array itself keys the cache: the labels, the footer and the power-balance
// renderer all read one render's range, and it is computed once. The map is
// weak, so the last tooltip of a destroyed chart cannot keep it alive.
const cache = new WeakMap<
  readonly TooltipItem<ChartType>[],
  Range | undefined
>();

// The values one tooltip shows at once. They scale it instead of the axis, so
// a tooltip of small values stays in watts while the axis is in kilowatts.
//
// Datasets of another quantity (a temperature, named tooltip fields) stay out,
// because they must not scale the others. A footer sum stays out as well: four
// rows of "400 W" keep more precision than four rows of "0,4 kW", and the sum
// below them follows the unit of the rows it adds up.
export const tooltipRange = (
  points?: readonly TooltipItem<ChartType>[],
): Range | undefined => {
  if (!points?.length) return;
  if (cache.has(points)) return cache.get(points);

  const range = computeRange(points);
  cache.set(points, range);

  return range;
};

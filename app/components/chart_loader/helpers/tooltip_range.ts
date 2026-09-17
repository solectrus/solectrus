// The range that scales one tooltip, read from the values it shows.
import type { ChartType, TooltipItem } from 'chart.js';

import { extractNumericValue } from './data_extents';
import type { DatasetWithId, Range } from './types';

// A dataset that measures a temperature. The unit comes from the sensor
// definition (Sensor::Definitions::Base#unit), so nothing has to read it off
// the dataset id.
export const isTemperatureDataset = (dataset: DatasetWithId): boolean =>
  dataset.unit === 'celsius';

// A dataset that shows a quantity of its own instead of the one the chart is
// scaled in: a temperature, or the named rows a scatter tooltip brings along
// (tooltipFields). It prints its own unit, so its values must not scale the
// other lines of the tooltip.
const hasOwnQuantity = (dataset: DatasetWithId): boolean =>
  Boolean(dataset.tooltipFields?.length) || isTemperatureDataset(dataset);

const computeRange = (
  points: readonly TooltipItem<ChartType>[],
): Range | undefined => {
  const values = points
    .filter((point) => !hasOwnQuantity(point.dataset as DatasetWithId))
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
// Datasets of another quantity stay out (#hasOwnQuantity), because they must
// not scale the others. A footer sum stays out as well: four rows of "400 W"
// keep more precision than four rows of "0,4 kW", and the sum below them
// follows the unit of the rows it adds up.
export const tooltipRange = (
  points?: readonly TooltipItem<ChartType>[],
): Range | undefined => {
  if (!points?.length) return;
  if (cache.has(points)) return cache.get(points);

  const range = computeRange(points);
  cache.set(points, range);

  return range;
};

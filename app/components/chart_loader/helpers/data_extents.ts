// Computes data extents (min/max, stacks) and detects overlap conditions.
import type { ChartData, ChartDataset } from 'chart.js';

// Extracts a numeric value from mixed dataset entries (number, range, or point).
export const extractNumericValue = (
  value: unknown,
  mode: 'max' | 'min',
): number | null => {
  if (typeof value === 'number') return value;
  if (Array.isArray(value))
    return mode === 'max' ? Math.max(...value) : Math.min(...value);
  if (value && typeof value === 'object' && 'y' in value) {
    const y = (value as { y: unknown }).y;
    if (typeof y === 'number') return y;
  }
  return null;
};

// Calculates the positive stacked maximum for the dataset collection.
export const maxOf = (data: ChartData): number => {
  const stackSums: Record<string, number[]> = {};
  let maxSum = 0;

  for (const dataset of data.datasets) {
    const stackKey = dataset.stack ?? '__default';
    if (dataset.data) {
      for (let index = 0; index < dataset.data.length; index++) {
        const value = dataset.data[index];
        const num = extractNumericValue(value, 'max');

        if (num !== null && num > 0) {
          stackSums[stackKey] ??= [];
          stackSums[stackKey][index] = (stackSums[stackKey][index] ?? 0) + num;
          maxSum = Math.max(maxSum, stackSums[stackKey][index]);
        }
      }
    }
  }

  return Math.ceil(maxSum);
};

// Calculates the negative stacked minimum for the dataset collection.
export const minOf = (data: ChartData): number => {
  const stackSums: Record<string, number[]> = {};
  let minSum = 0;

  for (const dataset of data.datasets) {
    const stackKey = dataset.stack ?? '__default';
    if (dataset.data) {
      for (let index = 0; index < dataset.data.length; index++) {
        const value = dataset.data[index];
        const num = extractNumericValue(value, 'min');

        if (num !== null && num < 0) {
          stackSums[stackKey] ??= [];
          stackSums[stackKey][index] = (stackSums[stackKey][index] ?? 0) + num;
          minSum = Math.min(minSum, stackSums[stackKey][index]);
        }
      }
    }
  }

  return Math.floor(minSum);
};

// Detects whether datasets overlap around zero (used for styling decisions).
export const isOverlapping = (datasets: ChartDataset[]): boolean => {
  if (datasets.length <= 1) return false;
  if (datasets.length > 2) return true;

  if (!datasets[0].data || !datasets[1].data) return false;

  const data1 = datasets[0].data.filter((x) => x);
  const data2 = datasets[1].data.filter((x) => x);

  const firstAllPositive = data1.every(
    (value) => typeof value === 'number' && value >= 0,
  );
  const secondAllNegative = data2.every(
    (value) => typeof value === 'number' && value <= 0,
  );
  if (firstAllPositive && secondAllNegative) return false;

  const firstAllNegative = data1.every(
    (value) => typeof value === 'number' && value <= 0,
  );
  const secondAllPositive = data2.every(
    (value) => typeof value === 'number' && value >= 0,
  );
  if (firstAllNegative && secondAllPositive) return false;

  return true;
};

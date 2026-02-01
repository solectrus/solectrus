// Applies default axis colors (ticks/grid/border) from CSS variables.
import { ChartOptions } from 'chart.js';

export type AxisColors = { tick: string; grid: string; zeroLine: string };

// Reads axis colors from CSS variables.
export const getAxisColors = (
  getCssVar: (name: string) => string,
): AxisColors => ({
  tick: getCssVar('--chart-axis-color'),
  grid: getCssVar('--chart-grid-color'),
  zeroLine: getCssVar('--chart-zero-line-color'),
});

// Applies default tick/grid/border colors to all configured scales.
export const applyAxisStyles = (
  options: ChartOptions,
  colors: AxisColors,
): void => {
  const { scales } = options;
  if (!scales) return;

  const applyToScale = (scale: Record<string, unknown> | undefined) => {
    if (!scale) return;

    const ticks = (scale.ticks as Record<string, unknown> | undefined) ?? {};
    if (!('color' in ticks)) ticks.color = colors.tick;
    scale.ticks = ticks;

    const grid = (scale.grid as Record<string, unknown> | undefined) ?? {};
    if (!('color' in grid)) grid.color = colors.grid;
    scale.grid = grid;

    const border = (scale.border as Record<string, unknown> | undefined) ?? {};
    if (!('color' in border)) border.color = colors.grid;
    scale.border = border;
  };

  applyToScale(scales.x as Record<string, unknown> | undefined);
  applyToScale(scales.y as Record<string, unknown> | undefined);
  applyToScale(scales.y1 as Record<string, unknown> | undefined);
};

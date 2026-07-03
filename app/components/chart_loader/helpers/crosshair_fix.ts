import { Chart } from 'chart.js';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

let applied = false;

// Fix for crosshair plugin drawing over the chart and tooltip
// https://github.com/AbelHeinsbroek/chartjs-plugin-crosshair/issues/48#issuecomment-1926758048
// Idempotent: several controllers register the plugin, but the wrapper must be
// installed only once - applying it twice would swallow the real afterDraw.
export const applyCrosshairFix = (): void => {
  if (applied) return;
  applied = true;

  const afterDraw = CrosshairPlugin.afterDraw.bind(CrosshairPlugin);
  CrosshairPlugin.afterDraw = () => {};
  CrosshairPlugin.afterDatasetsDraw = (
    chart: Chart,
    args: unknown,
    options: unknown,
  ): void => {
    // Crosshair plugin adds this property to the chart instance
    if ('crosshair' in chart) afterDraw(chart, args, options);
  };
};

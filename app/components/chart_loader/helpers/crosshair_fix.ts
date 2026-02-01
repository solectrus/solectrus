import { Chart } from 'chart.js';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

// Fix for crosshair plugin drawing over the chart and tooltip
// https://github.com/AbelHeinsbroek/chartjs-plugin-crosshair/issues/48#issuecomment-1926758048
export const applyCrosshairFix = (): void => {
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

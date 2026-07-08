import { Chart } from 'chart.js';
import { CrosshairPlugin } from 'chartjs-plugin-crosshair';

let applied = false;

// Global Chart.js setup, applied once before any chart renders. Shared by the
// generic chart_loader and the bespoke amortization chart so both behave and
// look identically. Idempotent: several controllers call it, but the patches
// must be installed only once.
export const applyChartDefaults = (): void => {
  if (applied) return;
  applied = true;

  // Chart.js renders axis ticks on the canvas with its built-in Helvetica
  // default; pin the family to the app font (Inter) so every chart matches the
  // surrounding UI. Raw canvas draws read it back via Chart.defaults.font.family.
  // Keep in sync with the --font-sans stack in application.css.
  Chart.defaults.font.family = 'Inter Variable, sans-serif';

  // Fix for the crosshair plugin drawing over the chart and tooltip:
  // https://github.com/AbelHeinsbroek/chartjs-plugin-crosshair/issues/48#issuecomment-1926758048
  // Move its painting from afterDraw to afterDatasetsDraw so it stays beneath
  // the datasets and tooltip.
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

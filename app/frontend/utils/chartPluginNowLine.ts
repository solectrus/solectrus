import type { Chart, Plugin } from 'chart.js';

// The dashed border of 1 px that marks now on the timeline of the car page
// (Car::DayTimeline::Component), in its color
const LINE_DASH = [3, 3];
const LINE_COLOR_VAR = '--color-muted';

interface NowLineConfig {
  enabled: boolean;
  // The step (ms) of the time series. The line goes back to the start of the
  // current step, where the measured values end.
  step?: number;
}

/**
 * Marks the current time with a dashed vertical line across the chart area,
 * in front of the datasets. The time comes from the browser at each draw,
 * so the line moves on with every redraw. Outside the x-axis it does not
 * show. The color is read once: a change of the theme builds the chart anew.
 */
export function buildNowLinePlugin(
  options: Record<string, unknown>,
  getCssVar: (name: string) => string,
): Plugin[] {
  const plugins = options.plugins as Record<string, unknown> | undefined;
  const config = plugins?.nowLine as NowLineConfig | undefined;
  if (!config?.enabled) return [];

  const color = getCssVar(LINE_COLOR_VAR);

  return [
    {
      id: 'nowLine',
      afterDatasetsDraw(chart: Chart) {
        const { ctx, scales, chartArea } = chart;
        if (!scales.x || !chartArea) return;

        const now = Date.now();
        const time = config.step ? now - (now % config.step) : now;
        const x = scales.x.getPixelForValue(time);
        if (x < chartArea.left || x > chartArea.right) return;

        ctx.save();
        ctx.strokeStyle = color;
        ctx.lineWidth = 1;
        ctx.setLineDash(LINE_DASH);
        ctx.beginPath();
        ctx.moveTo(x, chartArea.top);
        ctx.lineTo(x, chartArea.bottom);
        ctx.stroke();
        ctx.restore();
      },
    },
  ];
}

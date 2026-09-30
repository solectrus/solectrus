// Draws the average of each group of bars as a dashed mark across the group.
// A line through the middle of the group would meet one bar at most, a mark as
// wide as the group meets the bar of every year.
import type { Chart, Plugin } from 'chart.js';

import type { ChartDataWithAverages, DatasetWithId } from './types';

// The share of a category its bars fill, the categoryPercentage Chart.js
// draws by default.
const GROUP_WIDTH = 0.8;

// The colors are read once per chart: a change of theme builds the chart anew.
export const buildAverageMarksPlugin = (
  getCssVar: (name: string) => string,
): Plugin => {
  const haloColor = getCssVar('--chart-point-border');
  const textColor = getCssVar('--chart-label-strong');

  return {
    id: 'averageMarks',
    afterDatasetsDraw(chart: Chart) {
      const { averages, datasets } = chart.data as ChartDataWithAverages;
      const { x, y } = chart.scales;
      if (!averages || !x || !y) return;

      const { ctx } = chart;
      const halfWidth =
        (x.width / chart.data.labels!.length) * (GROUP_WIDTH / 2);

      // One set of marks per sensor, in the color of its newest year: the last
      // of its datasets, drawn in the full color of the sensor.
      Object.entries(averages).forEach(([sensorName, values]) => {
        const newest = (datasets as DatasetWithId[])
          .filter((dataset) => dataset.sensorName === sensorName)
          .at(-1);
        if (!newest) return;

        ctx.save();
        ctx.beginPath();
        values.forEach((average, index) => {
          if (average === null) return;

          const center = x.getPixelForValue(index);
          const top = y.getPixelForValue(average);
          ctx.moveTo(center - halfWidth, top);
          ctx.lineTo(center + halfWidth, top);
        });

        // A halo in the color of the background keeps the mark apart from the
        // bars. The mark itself is the color of the sensor mixed with the color
        // of the text: lighter on a dark background, darker on a light one.
        ctx.setLineDash([5, 3]);
        ctx.lineWidth = 4;
        ctx.strokeStyle = haloColor;
        ctx.stroke();
        ctx.lineWidth = 2;
        ctx.strokeStyle = `color-mix(in srgb, ${newest.tooltipColor}, ${textColor})`;
        ctx.stroke();
        ctx.restore();
      });
    },
  };
};

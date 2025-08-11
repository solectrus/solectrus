import {
  Chart,
  ChartArea,
  ChartDataset,
  ScriptableLineSegmentContext,
} from 'chart.js';

// Helper type to allow setting the segment option on line datasets (Chart.js supports it but it's not on base type)
type LineDatasetWithSegment = ChartDataset<'line'> & {
  segment?: {
    borderColor: (ctx: ScriptableLineSegmentContext) => string;
  };
};

// Map temperature to colors
const COLD_TEMP = -10;
const HOT_TEMP = 40;
const COLD_COLOR = '#42a5f5'; // light blue
const HOT_COLOR = '#ef5350'; // light red

export default class ChartGradientTemperature {
  constructor(private readonly chartType: string) {}

  applyToDataset(dataset: ChartDataset): void {
    switch (this.chartType) {
      case 'bar':
        return this.applyToBarDataset(dataset as ChartDataset<'bar'>);

      case 'line':
        return this.applyToLineDataset(dataset as ChartDataset<'line'>);
    }
  }

  // Apply temperature gradient styling for bar charts
  applyToBarDataset(dataset: ChartDataset<'bar'>): void {
    // Bar charts: vertical gradient for min-max columns
    dataset.backgroundColor = (context: {
      chart: Chart;
      datasetIndex: number;
    }) => {
      const { ctx, chartArea } = context.chart;
      if (chartArea)
        return this.createBarGradient(
          ctx,
          context.chart,
          chartArea,
          context.datasetIndex,
        );
    };

    dataset.borderWidth = 0;
  }

  // Apply temperature gradient styling for line charts
  applyToLineDataset(dataset: ChartDataset<'line'>): void {
    // Line charts: segment colors + vertical fill
    const data = dataset.data as number[];
    const segmentColors: string[] = [];

    for (let i = 0; i < data.length - 1; i++) {
      const currentTemp = data[i];
      const nextTemp = data[i + 1];

      if (currentTemp != null && nextTemp != null) {
        const avgTemp = (currentTemp + nextTemp) / 2;
        segmentColors.push(this.getColorForTemperature(avgTemp));
      } else if (currentTemp != null) {
        segmentColors.push(this.getColorForTemperature(currentTemp));
      } else if (nextTemp != null) {
        segmentColors.push(this.getColorForTemperature(nextTemp));
      } else {
        segmentColors.push('#000000');
      }
    }

    const lineDataset = dataset as LineDatasetWithSegment;
    lineDataset.segment = {
      borderColor: (ctx: ScriptableLineSegmentContext) =>
        segmentColors[ctx.p0DataIndex] || '#000000',
    };

    dataset.backgroundColor = (context: {
      chart: Chart;
      datasetIndex: number;
    }) => {
      const { ctx, chartArea } = context.chart;
      if (chartArea)
        return this.createVerticalFill(
          ctx,
          context.chart,
          chartArea,
          context.datasetIndex,
        );
    };

    dataset.borderWidth = 2;
  }

  private getColorForTemperature(temp: number): string {
    // Clamp temperature to our range
    const clampedTemp = Math.max(COLD_TEMP, Math.min(HOT_TEMP, temp));

    // Calculate ratio (0 = cold/blue, 1 = hot/red)
    const ratio = (clampedTemp - COLD_TEMP) / (HOT_TEMP - COLD_TEMP);

    // Interpolate between blue and red
    return this.interpolateColor(COLD_COLOR, HOT_COLOR, ratio);
  }

  private interpolateColor(
    color1: string,
    color2: string,
    ratio: number,
  ): string {
    const [r1, g1, b1] = [
      color1.slice(1, 3),
      color1.slice(3, 5),
      color1.slice(5, 7),
    ].map((x) => parseInt(x, 16));
    const [r2, g2, b2] = [
      color2.slice(1, 3),
      color2.slice(3, 5),
      color2.slice(5, 7),
    ].map((x) => parseInt(x, 16));

    const r = Math.round(r1 + (r2 - r1) * ratio);
    const g = Math.round(g1 + (g2 - g1) * ratio);
    const b = Math.round(b1 + (b2 - b1) * ratio);

    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  private createEmptyGradient(gradient: CanvasGradient): CanvasGradient {
    gradient.addColorStop(0, 'rgba(0,0,0,0)');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');
    return gradient;
  }

  private addTemperatureStops(
    gradient: CanvasGradient,
    startTemp: number,
    endTemp: number,
    opacityFn: (position: number) => number,
  ): void {
    for (let i = 0; i <= 10; i++) {
      const position = i / 10;
      const temp = startTemp + (endTemp - startTemp) * position;
      const color = this.getColorForTemperature(temp);
      const [r, g, b] = [
        color.slice(1, 3),
        color.slice(3, 5),
        color.slice(5, 7),
      ].map((x) => parseInt(x, 16));

      gradient.addColorStop(
        position,
        `rgba(${r}, ${g}, ${b}, ${opacityFn(position)})`,
      );
    }
  }

  private createVerticalFill(
    ctx: CanvasRenderingContext2D,
    chart: Chart,
    chartArea: ChartArea,
    datasetIndex: number,
  ): CanvasGradient {
    const zeroY = chart.scales.y.getPixelForValue(0);
    const gradient = ctx.createLinearGradient(
      0,
      Math.min(zeroY, chartArea.bottom),
      0,
      chartArea.top,
    );

    const data = chart.data.datasets[datasetIndex].data as number[];
    const temps = data.filter((temp) => temp != null);

    if (temps.length === 0) return this.createEmptyGradient(gradient);

    const minTemp = Math.min(...temps);
    const maxTemp = Math.max(...temps);
    const startTemp = minTemp < 0 ? minTemp : 0;
    const endTemp = maxTemp > 0 ? maxTemp : 0;

    this.addTemperatureStops(
      gradient,
      startTemp,
      endTemp,
      (position) => 0.05 + 0.25 * position,
    );
    return gradient;
  }

  private createBarGradient(
    ctx: CanvasRenderingContext2D,
    chart: Chart,
    chartArea: ChartArea,
    datasetIndex: number,
  ): CanvasGradient {
    const gradient = ctx.createLinearGradient(
      0,
      chartArea.bottom,
      0,
      chartArea.top,
    );
    const data = chart.data.datasets[datasetIndex].data as number[][];

    const allTemps: number[] = [];
    data.forEach((value) => {
      if (Array.isArray(value) && value.length === 2) {
        allTemps.push(...value.filter((temp) => temp != null));
      }
    });

    if (allTemps.length === 0) return this.createEmptyGradient(gradient);

    const minTemp = Math.min(...allTemps);
    const maxTemp = Math.max(...allTemps);

    this.addTemperatureStops(gradient, minTemp, maxTemp, () => 0.8);
    return gradient;
  }
}

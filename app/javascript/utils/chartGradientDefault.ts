import { Chart, ChartArea, ChartDataset } from 'chart.js';

export default class ChartGradientDefault {
  private readonly originalColor: string;
  private readonly isNegative: boolean;
  private readonly basePosition: number;
  private readonly extent: number;
  private readonly minAlpha: number;
  private readonly maxAlpha: number;

  constructor(
    dataset: ChartDataset,
    min: number,
    max: number,
    minAlpha: number,
  ) {
    // Remember original color
    this.originalColor = dataset.backgroundColor as string;

    const extent = min < 0 ? Math.abs(max) + Math.abs(min) : max;
    this.basePosition = max / extent;
    this.isNegative = dataset.data.some((value) =>
      typeof value === 'number' ? value < 0 : false,
    );

    const datasetMin = this.minOfDataset(dataset);
    const datasetMax = this.maxOfDataset(dataset);
    const datasetExtent =
      datasetMin < 0 ? Math.abs(datasetMax) + Math.abs(datasetMin) : datasetMax;

    this.extent = datasetExtent / extent;
    this.minAlpha = minAlpha;
    // Stacked bar must not be gradiented, just use the given Alpha
    this.maxAlpha = dataset.stack ? minAlpha : 1;
  }

  // For caching the gradient so we don't have to recreate it every time
  private width?: number;
  private height?: number;
  private gradient?: CanvasGradient;

  canvasGradient(
    ctx: CanvasRenderingContext2D,
    chartArea: ChartArea,
  ): CanvasGradient {
    const { width: chartWidth, height: chartHeight } = chartArea;

    // If there's no gradient or the chart dimensions have changed, create a new gradient
    if (
      !this.gradient ||
      this.width !== chartWidth ||
      this.height !== chartHeight
    ) {
      this.width = chartWidth;
      this.height = chartHeight;
      this.gradient = this.createGradient(ctx, chartArea);
    }

    return this.gradient;
  }

  private createGradient(
    ctx: CanvasRenderingContext2D,
    chartArea: ChartArea,
  ): CanvasGradient {
    const start = this.gradientStart(chartArea.height);
    const end = this.gradientEnd(chartArea.height) || 0;
    const gradient = ctx.createLinearGradient(0, start, 0, end);

    const colorOpaque = this.hexToRGBA(
      this.originalColor,
      Math.min(Math.max(this.extent, this.minAlpha), this.maxAlpha),
    );
    const colorTransparent = this.hexToRGBA(this.originalColor, this.minAlpha);

    if (this.isNegative) {
      gradient.addColorStop(0, colorTransparent);
      gradient.addColorStop(1, colorOpaque);
    } else {
      gradient.addColorStop(0, colorOpaque);
      gradient.addColorStop(1, colorTransparent);
    }

    return gradient;
  }

  private gradientStart(height: number): number {
    if (this.isNegative) return height * this.basePosition;

    return 0;
  }

  private gradientEnd(height: number): number {
    if (this.isNegative) return height;

    return height * this.basePosition;
  }

  applyToDataset(dataset: ChartDataset): void {
    // Replace background color with gradient
    dataset.backgroundColor = (context: { chart: Chart; type: string }) => {
      const { ctx, chartArea } = context.chart;

      if (chartArea) return this.canvasGradient(ctx, chartArea);
    };

    // Use original color for border
    dataset.borderColor = this.originalColor;
  }

  private minOfDataset(dataset: ChartDataset): number {
    const mapped = dataset.data.map((value) => {
      if (Array.isArray(value)) return Math.min(...value);
      if (typeof value === 'number') return value;

      return Number.POSITIVE_INFINITY;
    });

    return Math.min(...mapped);
  }

  private maxOfDataset(dataset: ChartDataset): number {
    const mapped = dataset.data.map((value) => {
      if (Array.isArray(value)) return Math.max(...value);
      if (typeof value === 'number') return value;

      return Number.NEGATIVE_INFINITY;
    });

    return Math.max(...mapped);
  }

  // Function to convert hex color code to RGB
  private hexToRGBA(hex: string, alpha: number): string {
    if (!/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(hex))
      throw new Error(`"${hex}" is not a valid hex color!`);
    if (alpha < 0) alpha = 0;
    if (alpha > 1) alpha = 1;

    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);

    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }
}

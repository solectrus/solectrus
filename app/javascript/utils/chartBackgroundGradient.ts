import { ChartArea } from 'chart.js';

export default class ChartBackgroundGradient {
  constructor(
    private readonly originalColor: string,
    private readonly isNegative: boolean,
    private readonly basePosition: number, // Vertical position of the x-Axis in the given Chart (between 0 and 1)
    private readonly extent: number, // Extent of the dataset in the given Chart (between 0 and 1)
    private readonly minAlpha: number,
    private readonly maxAlpha: number,
    private readonly enableHatch: boolean = false, // Optional: Enable hatching
  ) {}

  // For caching the gradient so we don't have to recreate it every time
  private width?: number;
  private height?: number;
  private gradient?: CanvasGradient | CanvasPattern;

  canvasGradient(
    ctx: CanvasRenderingContext2D,
    chartArea: ChartArea,
  ): CanvasGradient | CanvasPattern {
    const { width: chartWidth, height: chartHeight } = chartArea;

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
  ): CanvasGradient | CanvasPattern {
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

    // If hatching is enabled, create a pattern with the original color
    if (this.enableHatch) {
      const pattern = this.createHatchPattern(ctx);
      return pattern || gradient;
    }

    return gradient;
  }

  private createHatchPattern(
    ctx: CanvasRenderingContext2D,
  ): CanvasPattern | null {
    const patternCanvas = document.createElement('canvas');
    patternCanvas.width = 6;
    patternCanvas.height = 6;

    const pCtx = patternCanvas.getContext('2d');
    if (!pCtx) return null;

    pCtx.strokeStyle = this.originalColor;
    pCtx.globalAlpha = 0.5;
    pCtx.lineWidth = 1;

    pCtx.beginPath();
    pCtx.moveTo(0, 0);
    pCtx.lineTo(6, 6);
    pCtx.stroke();

    return ctx.createPattern(patternCanvas, 'repeat');
  }

  private gradientStart(height: number): number {
    return this.isNegative ? height * this.basePosition : 0;
  }

  private gradientEnd(height: number): number {
    return this.isNegative ? height : height * this.basePosition;
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

import { Chart, ChartData, ChartDataset, ChartType } from 'chart.js';

import ChartBackgroundGradient from '@/utils/chartGradientDefault';
import { resolveColor, colorToRgba, lightenColor, toRgb } from '@/utils/color';

import type {
  ColorScaleStop,
  DatasetWithId,
  LineDatasetWithSegment,
  ResolvedColorScaleStop,
} from './types';

export class ChartColorManager {
  private readonly colorClassCache = new Map<string, string>();
  private readonly hatchPatternCache = new Map<string, CanvasPattern>();
  private typeValue: ChartType = 'line';

  constructor(
    private readonly isOverlapping: (datasets: ChartDataset[]) => boolean,
  ) {}

  setChartType(typeValue: ChartType): void {
    this.typeValue = typeValue;
  }

  clearCache(): void {
    this.colorClassCache.clear();
    this.hatchPatternCache.clear();
  }

  applyDatasetColors(
    data: ChartData,
    minValue: number,
    maxValue: number,
  ): void {
    const isDarkTheme = document.documentElement.classList.contains('dark');

    const lineColorFactor =
      data.datasets.length > 1
        ? isDarkTheme
          ? 0.3
          : 0.6
        : isDarkTheme
          ? 0.2
          : 0;

    // Resolve colorClass to actual CSS colors
    for (const dataset of data.datasets) {
      const datasetWithId = dataset as DatasetWithId;

      if (datasetWithId.colorClass) {
        const resolvedColor = this.resolveColorClass(datasetWithId.colorClass);
        if (resolvedColor) {
          const lineDataset = dataset as ChartDataset<'line'>;
          const isStacked = lineDataset.stack !== undefined;
          const lineColor =
            isStacked || isDarkTheme
              ? (lightenColor(resolvedColor, lineColorFactor) ?? resolvedColor)
              : resolvedColor;

          if (datasetWithId.hatchFill) {
            dataset.backgroundColor = (context: {
              chart: Chart;
            }): CanvasPattern | string | undefined => {
              const { ctx, chartArea } = context.chart;
              if (!chartArea) return;
              return this.createHatchPattern(ctx, resolvedColor);
            };
            dataset.borderColor = lineColor;
            continue;
          }

          // If opacities array is provided, create color array with color-mix
          // Only lighten line color for stacked datasets to distinguish border from fill

          dataset.backgroundColor = datasetWithId.opacities?.length
            ? datasetWithId.opacities.map((opacity) =>
                colorToRgba(resolvedColor, opacity),
              )
            : resolvedColor;
          dataset.borderColor = lineColor;
        }
      }
    }

    const minAlpha = this.getMinAlpha(data);

    for (const dataset of data.datasets) {
      if (!dataset.data) continue;

      const datasetWithId = dataset as DatasetWithId;
      const resolvedScale = this.resolveColorScale(datasetWithId.colorScale);

      if (resolvedScale && this.applyColorScale(dataset, resolvedScale)) {
        continue;
      }

      if (
        maxValue > minValue &&
        !Array.isArray(dataset.backgroundColor) &&
        !datasetWithId.noGradient
      ) {
        // Apply gradient only when backgroundColor is a single color (not an array)
        // and noGradient is not set
        this.setDefaultGradient(dataset, minValue, maxValue, minAlpha);
      }
    }
  }

  private getMinAlpha(data: ChartData): number {
    const isSparseLine =
      this.typeValue === 'line' && !this.isOverlapping(data.datasets);
    return isSparseLine ? 0.2 : 0.7;
  }

  private setDefaultGradient(
    dataset: ChartDataset,
    min: number,
    max: number,
    minAlpha: number,
  ): void {
    const backgroundGradient = new ChartBackgroundGradient(
      dataset,
      min,
      max,
      minAlpha,
    );

    backgroundGradient.applyToDataset(dataset);
  }

  private resolveColorScale(
    scale?: ColorScaleStop[],
  ): ResolvedColorScaleStop[] | undefined {
    if (!scale?.length) return;

    const resolved = scale
      .map((stop) => {
        const color = this.resolveColorClass(stop.colorClass);
        if (!color) return;
        return { value: stop.value, color };
      })
      .filter(Boolean) as ResolvedColorScaleStop[];

    if (resolved.length < 2) return;

    return resolved.sort((a, b) => a.value - b.value);
  }

  private applyColorScale(
    dataset: ChartDataset,
    scale: ResolvedColorScaleStop[],
  ): boolean {
    switch (this.typeValue) {
      case 'bar':
        this.applyColorScaleToBar(dataset as ChartDataset<'bar'>, scale);
        return true;
      case 'line':
        this.applyColorScaleToLine(dataset as ChartDataset<'line'>, scale);
        return true;
    }

    return false;
  }

  private applyColorScaleToBar(
    dataset: ChartDataset<'bar'>,
    scale: ResolvedColorScaleStop[],
  ): void {
    dataset.backgroundColor = (context: {
      chart: Chart;
      datasetIndex: number;
    }) => {
      const { ctx, chartArea } = context.chart;
      if (chartArea)
        return this.createBarScaleGradient(
          ctx,
          context.chart,
          chartArea,
          context.datasetIndex,
          scale,
        );
    };

    dataset.borderWidth = 0;
  }

  private applyColorScaleToLine(
    dataset: ChartDataset<'line'>,
    scale: ResolvedColorScaleStop[],
  ): void {
    const lineDataset = dataset as LineDatasetWithSegment;
    const defaultColor = this.colorWithOpacity(scale[0].color) ?? '#000000';

    lineDataset.segment = {
      borderColor: (ctx: { p0DataIndex: number }) => {
        const data = dataset.data as number[];
        const index = ctx.p0DataIndex;

        if (index >= data.length - 1) return defaultColor;

        const current = data[index];
        const next = data[index + 1];

        if (current != null && next != null) {
          const avg = (current + next) / 2;
          return this.colorForValue(avg, scale) ?? defaultColor;
        }
        if (current != null)
          return this.colorForValue(current, scale) ?? defaultColor;
        if (next != null)
          return this.colorForValue(next, scale) ?? defaultColor;

        return defaultColor;
      },
    };

    dataset.backgroundColor = (context: {
      chart: Chart;
      datasetIndex: number;
    }) => {
      const { ctx, chartArea } = context.chart;
      if (chartArea)
        return this.createLineScaleGradient(
          ctx,
          context.chart,
          chartArea,
          context.datasetIndex,
          scale,
        );
    };

    dataset.borderWidth = 2;
  }

  private createLineScaleGradient(
    ctx: CanvasRenderingContext2D,
    chart: Chart,
    chartArea: { top: number; bottom: number },
    datasetIndex: number,
    scale: ResolvedColorScaleStop[],
  ): CanvasGradient {
    const zeroY = chart.scales.y.getPixelForValue(0);
    const startY = Math.min(zeroY, chartArea.bottom);
    const endY = chartArea.top;
    const values = this.collectLineValues(chart, datasetIndex);

    return this.createScaleGradient({
      ctx,
      startY,
      endY,
      scale,
      values,
      opacityFn: (position) => 0.05 + 0.25 * position,
      emptyWhenFlat: true,
    });
  }

  private createBarScaleGradient(
    ctx: CanvasRenderingContext2D,
    chart: Chart,
    chartArea: { top: number; bottom: number },
    datasetIndex: number,
    scale: ResolvedColorScaleStop[],
  ): CanvasGradient {
    const values = this.collectBarValues(chart, datasetIndex);

    return this.createScaleGradient({
      ctx,
      startY: chartArea.bottom,
      endY: chartArea.top,
      scale,
      values,
      opacityFn: () => 0.8,
      emptyWhenFlat: false,
    });
  }

  private collectLineValues(chart: Chart, datasetIndex: number): number[] {
    const data = chart.data.datasets[datasetIndex].data as number[];
    return data.filter((value) => value != null);
  }

  private collectBarValues(chart: Chart, datasetIndex: number): number[] {
    const data = chart.data.datasets[datasetIndex].data as number[][];
    const values: number[] = [];

    for (const value of data) {
      if (Array.isArray(value) && value.length === 2) {
        values.push(...value.filter((temp) => temp != null));
      }
    }

    return values;
  }

  private createScaleGradient({
    ctx,
    startY,
    endY,
    scale,
    values,
    opacityFn,
    emptyWhenFlat,
  }: {
    ctx: CanvasRenderingContext2D;
    startY: number;
    endY: number;
    scale: ResolvedColorScaleStop[];
    values: number[];
    opacityFn: (position: number) => number;
    emptyWhenFlat: boolean;
  }): CanvasGradient {
    const gradient = ctx.createLinearGradient(0, startY, 0, endY);
    if (values.length === 0) return this.createEmptyGradient(gradient);

    const minValue = Math.min(...values);
    const maxValue = Math.max(...values);

    if (emptyWhenFlat && minValue === maxValue) {
      return this.createEmptyGradient(gradient);
    }

    this.addScaleStops(gradient, scale, minValue, maxValue, opacityFn);
    return gradient;
  }

  private createEmptyGradient(gradient: CanvasGradient): CanvasGradient {
    gradient.addColorStop(0, 'rgba(0,0,0,0)');
    gradient.addColorStop(1, 'rgba(0,0,0,0)');
    return gradient;
  }

  private addScaleStops(
    gradient: CanvasGradient,
    scale: ResolvedColorScaleStop[],
    startValue: number,
    endValue: number,
    opacityFn: (position: number) => number,
  ): void {
    const minValue = Math.min(startValue, endValue);
    const maxValue = Math.max(startValue, endValue);

    if (minValue === maxValue) {
      const color = this.colorForValue(minValue, scale, opacityFn(0));
      if (color) gradient.addColorStop(0, color);
      if (color) gradient.addColorStop(1, color);
      return;
    }

    const stops = [
      minValue,
      ...scale
        .map((stop) => stop.value)
        .filter((value) => value > minValue && value < maxValue),
      maxValue,
    ];

    for (const value of stops) {
      const position = (value - minValue) / (maxValue - minValue);
      const color = this.colorForValue(value, scale, opacityFn(position));
      if (color) gradient.addColorStop(position, color);
    }
  }

  private colorForValue(
    value: number,
    scale: ResolvedColorScaleStop[],
    opacity?: number,
  ): string | undefined {
    const sorted = scale;
    const minStop = sorted[0];
    const maxStop = sorted[sorted.length - 1];

    if (value <= minStop.value)
      return this.colorWithOpacity(minStop.color, opacity);
    if (value >= maxStop.value)
      return this.colorWithOpacity(maxStop.color, opacity);

    let lower = minStop;
    let upper = maxStop;

    for (const stop of sorted) {
      if (stop.value <= value) lower = stop;
      if (stop.value >= value) {
        upper = stop;
        break;
      }
    }

    const range = upper.value - lower.value;
    if (range <= 0) return this.colorWithOpacity(lower.color, opacity ?? 1);

    const ratio = (value - lower.value) / range;
    return this.interpolateColor(lower.color, upper.color, ratio, opacity);
  }

  private interpolateColor(
    from: string,
    to: string,
    ratio: number,
    opacity?: number,
  ): string | undefined {
    const start = toRgb(from);
    const end = toRgb(to);
    if (!start || !end) return;

    const clamped = Math.min(Math.max(ratio, 0), 1);
    const r = Math.round(start.r + (end.r - start.r) * clamped);
    const g = Math.round(start.g + (end.g - start.g) * clamped);
    const b = Math.round(start.b + (end.b - start.b) * clamped);

    const startAlpha = start.a ?? 1;
    const endAlpha = end.a ?? 1;
    let alpha = startAlpha + (endAlpha - startAlpha) * clamped;
    if (opacity !== undefined) alpha *= opacity;

    if (opacity === undefined && alpha >= 1) {
      return `#${this.toHex(r)}${this.toHex(g)}${this.toHex(b)}`;
    }

    return `rgba(${r}, ${g}, ${b}, ${Math.min(Math.max(alpha, 0), 1)})`;
  }

  private colorWithOpacity(
    color: string,
    opacity?: number,
  ): string | undefined {
    const rgb = toRgb(color);
    if (!rgb) return;

    if (opacity === undefined) {
      if (rgb.a === undefined || rgb.a >= 1) {
        return `#${this.toHex(rgb.r)}${this.toHex(rgb.g)}${this.toHex(rgb.b)}`;
      }
      return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${rgb.a})`;
    }

    const baseAlpha = rgb.a ?? 1;
    const finalAlpha = Math.min(Math.max(baseAlpha * opacity, 0), 1);
    return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${finalAlpha})`;
  }

  private toHex(value: number): string {
    return value.toString(16).padStart(2, '0');
  }

  private resolveColorClass(colorClass: string): string | undefined {
    const cached = this.colorClassCache.get(colorClass);
    if (cached) return cached;

    const element = document.createElement('div');
    element.className = colorClass;
    element.style.position = 'absolute';
    element.style.left = '-9999px';
    element.style.width = '1px';
    element.style.height = '1px';
    element.style.pointerEvents = 'none';
    document.body.appendChild(element);

    const computed = window.getComputedStyle(element).backgroundColor;
    document.body.removeChild(element);

    if (
      !computed ||
      computed === 'transparent' ||
      computed === 'rgba(0, 0, 0, 0)'
    )
      return;

    const resolved = resolveColor(computed);
    if (!resolved) return;

    this.colorClassCache.set(colorClass, resolved);
    return resolved;
  }

  private createHatchPattern(
    ctx: CanvasRenderingContext2D,
    color: string,
  ): CanvasPattern | string {
    const cached = this.hatchPatternCache.get(color);
    if (cached) return cached;

    const size = 8;
    const canvas = document.createElement('canvas');
    canvas.width = size;
    canvas.height = size;

    const context = canvas.getContext('2d');
    if (!context) return colorToRgba(color, 0.15) ?? color;

    const lineColor = colorToRgba(color, 0.6) ?? color;
    context.strokeStyle = lineColor;
    context.lineWidth = 1;
    context.lineCap = 'butt';
    context.lineJoin = 'miter';
    context.beginPath();
    context.moveTo(0, size);
    context.lineTo(size, 0);
    context.stroke();

    const pattern = ctx.createPattern(canvas, 'repeat');
    if (!pattern) return lineColor;

    this.hatchPatternCache.set(color, pattern);
    return pattern;
  }
}

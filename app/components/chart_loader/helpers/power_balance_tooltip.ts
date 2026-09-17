// Renders and positions the custom HTML tooltip for power-balance charts.
import type { Chart, ChartType, Color, TooltipItem } from 'chart.js';

import { tooltipRange } from './tooltip_range';
import {
  colorToString,
  createTooltipElement,
  escapeHtml,
  hideTooltip,
  positionTooltipElement,
} from './tooltip_utils';
import type { DatasetWithId, Range } from './types';

type TooltipModel = {
  opacity: number;
  dataPoints?: TooltipItem<ChartType>[];
  labelColors?: Array<{ backgroundColor: Color; borderColor: Color }>;
  title?: string | string[];
  caretX: number;
};

export type TooltipContext = {
  chart: Chart;
  tooltip: TooltipModel;
};

type TooltipRow = {
  dp: TooltipItem<ChartType>;
  color?: { backgroundColor: Color; borderColor: Color };
  datasetId: string;
  order: number;
};

// Custom HTML tooltip renderer for power-balance charts.
export default class PowerBalanceTooltip {
  private tooltip?: HTMLDivElement;
  private readonly formatValue: (value: number, range?: Range) => string;
  private readonly sourceLabel: string;
  private readonly usageLabel: string;

  constructor(
    formatValue: (value: number, range?: Range) => string,
    sourceLabel: string,
    usageLabel: string,
  ) {
    this.formatValue = formatValue;
    this.sourceLabel = sourceLabel;
    this.usageLabel = usageLabel;
  }

  destroy() {
    this.tooltip?.remove();
    this.tooltip = undefined;
  }

  render(
    context: TooltipContext,
    sourceIds: Set<string>,
    usageIds: Set<string>,
    orderMap: Map<string, number>,
  ) {
    const { chart, tooltip } = context;
    const tooltipEl = this.getTooltipElement();

    if (!tooltip || tooltip.opacity === 0) return hideTooltip(tooltipEl);

    const dataPoints = tooltip.dataPoints;

    if (!dataPoints?.length) return hideTooltip(tooltipEl);

    const items = dataPoints
      .map((dp, index) => {
        const datasetId = (dp.dataset as DatasetWithId)?.id ?? '';
        return {
          dp,
          datasetId,
          order: orderMap.get(datasetId) ?? Number.MAX_SAFE_INTEGER,
          color: tooltip.labelColors?.[index],
        };
      })
      .sort((a, b) => a.order - b.order);

    const isForecastOnly = items.every(
      (item) => item.datasetId === 'inverter_power_forecast',
    );

    const sourceItems = isForecastOnly
      ? []
      : items.filter((item) => sourceIds.has(item.datasetId));
    const usageItems = isForecastOnly
      ? []
      : items.filter((item) => usageIds.has(item.datasetId));

    // The rows of one render share one unit, so the range covers them all.
    // Pass the array Chart.js built, because it keys the shared cache.
    const range = tooltipRange(dataPoints);

    const contentEl = tooltipEl.querySelector(
      '.chart-tooltip-content',
    ) as HTMLElement;
    contentEl.innerHTML = isForecastOnly
      ? this.buildSimpleTooltipHtml(
          this.normalizeTitle(tooltip.title),
          items,
          range,
        )
      : this.buildTooltipHtml(
          this.normalizeTitle(tooltip.title),
          sourceItems,
          usageItems,
          range,
        );

    this.positionTooltip(tooltipEl, chart, tooltip);
  }

  private getTooltipElement(): HTMLDivElement {
    if (this.tooltip) return this.tooltip;

    this.tooltip = createTooltipElement('chartjs-power-balance-tooltip');
    return this.tooltip;
  }

  private positionTooltip(
    tooltipEl: HTMLDivElement,
    chart: Chart,
    tooltip: TooltipModel,
  ) {
    const canvasRect = chart.canvas.getBoundingClientRect();
    const axisScale = chart.scales.y;
    const axisY =
      axisScale && typeof axisScale.getPixelForValue === 'function'
        ? axisScale.getPixelForValue(0)
        : chart.chartArea.bottom;
    const centerY = canvasRect.top + axisY;

    positionTooltipElement(tooltipEl, chart, tooltip.caretX, centerY);
  }

  private buildTooltipHtml(
    title: string | undefined,
    sourceItems: TooltipRow[],
    usageItems: TooltipRow[],
    range?: Range,
  ): string {
    const sourceRows = sourceItems
      .map((item) => this.renderRow(item, range))
      .join('');
    const usageRows = usageItems
      .map((item) => this.renderRow(item, range))
      .join('');
    const separator =
      sourceRows && usageRows
        ? '<div class="label-value-separator my-1"></div>'
        : '';

    const titleHtml = title
      ? `<div class="chart-tooltip-title">${escapeHtml(title)}</div>`
      : '';

    return `
      ${titleHtml}
      <div class="chart-tooltip-group">
        <div class="chart-tooltip-heading">${escapeHtml(this.sourceLabel)}</div>
        ${sourceRows}
      </div>
      ${separator}
      <div class="chart-tooltip-group">
        <div class="chart-tooltip-heading">${escapeHtml(this.usageLabel)}</div>
        ${usageRows}
      </div>
    `;
  }

  private buildSimpleTooltipHtml(
    title: string | undefined,
    items: TooltipRow[],
    range?: Range,
  ): string {
    const rows = items.map((item) => this.renderRow(item, range)).join('');
    const titleHtml = title
      ? `<div class="chart-tooltip-title">${escapeHtml(title)}</div>`
      : '';

    return `
      ${titleHtml}
      <div class="chart-tooltip-group">
        ${rows}
      </div>
    `;
  }

  private normalizeTitle(title?: string | string[]): string | undefined {
    if (!title) return;
    if (Array.isArray(title)) return title.filter(Boolean).join(' ');
    return title;
  }

  private renderRow(item: TooltipRow, range?: Range): string {
    const value = item.dp.parsed?.y;
    if (value == null) return '';

    const label = escapeHtml(String(item.dp.dataset?.label ?? ''));
    const formattedValue = escapeHtml(this.formatValue(value, range));
    const backgroundColor = colorToString(
      item.color?.backgroundColor ?? 'transparent',
    );

    return `
      <div class="label-value-row">
        <div class="chart-tooltip-label">
          <span class="label-value-swatch" style="background:${backgroundColor};"></span>
          <span class="chart-tooltip-name">${label}</span>
        </div>
        <div class="chart-tooltip-value">${formattedValue}</div>
      </div>
    `;
  }
}

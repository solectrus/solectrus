// Renders and positions the custom HTML tooltip for power-balance charts.
import type { Chart, Color } from 'chart.js';

type TooltipModel = {
  opacity: number;
  dataPoints?: Array<{
    dataset: { id?: string; label?: string };
    parsed: { y?: number | null };
  }>;
  labelColors?: Array<{ backgroundColor: Color; borderColor: Color }>;
  title?: string | string[];
  caretX: number;
};

export type TooltipContext = {
  chart: Chart;
  tooltip: TooltipModel;
};

type TooltipItem = {
  dp: {
    dataset: { label?: string; id?: string };
    parsed: { y?: number | null };
  };
  color?: { backgroundColor: Color; borderColor: Color };
  datasetId: string;
  order: number;
};

// Custom HTML tooltip renderer for power-balance charts.
export default class PowerBalanceTooltip {
  private tooltip?: HTMLDivElement;
  private readonly formatValue: (value: number, useKilo: boolean) => string;
  private readonly sourceLabel: string;
  private readonly usageLabel: string;

  constructor(
    formatValue: (value: number, useKilo: boolean) => string,
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

    if (!tooltip || tooltip.opacity === 0) return this.hideTooltip(tooltipEl);

    const dataPoints = (tooltip.dataPoints ?? []) as Array<{
      dataset: { id?: string; label?: string };
      parsed: { y?: number | null };
    }>;

    if (!dataPoints.length) return this.hideTooltip(tooltipEl);

    const items = dataPoints
      .map((dp, index) => {
        const datasetId = dp.dataset?.id ?? '';
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
    const useKilo = this.shouldUseKilo(items);

    const contentEl = tooltipEl.querySelector(
      '.chart-tooltip-content',
    ) as HTMLElement;
    contentEl.innerHTML = isForecastOnly
      ? this.buildSimpleTooltipHtml(
          this.normalizeTitle(tooltip.title),
          items,
          useKilo,
        )
      : this.buildTooltipHtml(
          this.normalizeTitle(tooltip.title),
          sourceItems,
          usageItems,
          useKilo,
        );

    this.positionTooltip(tooltipEl, chart, tooltip);
  }

  private getTooltipElement(): HTMLDivElement {
    if (this.tooltip) return this.tooltip;

    const tooltipEl = document.createElement('div');
    tooltipEl.className = 'chartjs-tooltip chartjs-power-balance-tooltip';

    const contentEl = document.createElement('div');
    contentEl.className = 'chart-tooltip-content';
    tooltipEl.appendChild(contentEl);

    document.body.appendChild(tooltipEl);
    this.tooltip = tooltipEl;

    return tooltipEl;
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

    this.resetTooltipPosition(tooltipEl);

    const tooltipWidth = tooltipEl.offsetWidth;
    const tooltipHeight = tooltipEl.offsetHeight;
    const viewportWidth = window.innerWidth;
    const margin = 12;
    const isMobileViewport = window.matchMedia('(max-width: 639px)').matches;

    const caretX = canvasRect.left + window.scrollX + tooltip.caretX;
    let left = 0;
    if (isMobileViewport) {
      left = caretX - tooltipWidth / 2;
    } else {
      const chartLeft = chart.chartArea.left;
      const chartRight = chart.chartArea.right;
      const spaceLeft = tooltip.caretX - chartLeft;
      const spaceRight = chartRight - tooltip.caretX;
      const preferRight = spaceRight >= spaceLeft;
      left = preferRight ? caretX + margin : caretX - tooltipWidth - margin;
    }

    const minLeft = window.scrollX + margin;
    const maxLeft = window.scrollX + viewportWidth - tooltipWidth - margin;
    if (left < minLeft) left = minLeft;
    if (left > maxLeft) left = maxLeft;

    let top = 0;
    if (isMobileViewport) {
      top = canvasRect.top + window.scrollY - tooltipHeight - margin;
    } else {
      const axisYPos = canvasRect.top + window.scrollY + axisY;
      top = axisYPos - tooltipHeight / 2;
    }
    const minTop = window.scrollY + margin;
    const maxTop = window.scrollY + window.innerHeight - tooltipHeight - margin;
    if (top < minTop) top = minTop;
    if (top > maxTop) top = maxTop;

    tooltipEl.style.left = `${left}px`;
    tooltipEl.style.top = `${top}px`;
    tooltipEl.style.opacity = '1';
    tooltipEl.style.visibility = 'visible';
  }

  private buildTooltipHtml(
    title: string | undefined,
    sourceItems: TooltipItem[],
    usageItems: TooltipItem[],
    useKilo: boolean,
  ): string {
    const sourceRows = sourceItems
      .map((item) => this.renderRow(item, useKilo))
      .join('');
    const usageRows = usageItems
      .map((item) => this.renderRow(item, useKilo))
      .join('');
    const separator =
      sourceRows && usageRows
        ? '<div class="chart-tooltip-separator"></div>'
        : '';

    const titleHtml = title
      ? `<div class="chart-tooltip-title">${this.escapeHtml(title)}</div>`
      : '';

    return `
      ${titleHtml}
      <div class="chart-tooltip-group">
        <div class="chart-tooltip-heading">${this.escapeHtml(this.sourceLabel)}</div>
        ${sourceRows}
      </div>
      ${separator}
      <div class="chart-tooltip-group">
        <div class="chart-tooltip-heading">${this.escapeHtml(this.usageLabel)}</div>
        ${usageRows}
      </div>
    `;
  }

  private buildSimpleTooltipHtml(
    title: string | undefined,
    items: TooltipItem[],
    useKilo: boolean,
  ): string {
    const rows = items.map((item) => this.renderRow(item, useKilo)).join('');
    const titleHtml = title
      ? `<div class="chart-tooltip-title">${this.escapeHtml(title)}</div>`
      : '';

    return `
      ${titleHtml}
      <div class="chart-tooltip-group">
        ${rows}
      </div>
    `;
  }

  private shouldUseKilo(items: TooltipItem[]): boolean {
    const values = items
      .map((item) => item.dp.parsed.y)
      .filter((value): value is number => typeof value === 'number');

    if (!values.length) return false;

    const nonZeroValues = values.filter((value) => value !== 0);
    if (!nonZeroValues.length) return false;

    return nonZeroValues.every((value) => Math.abs(value) > 500);
  }

  private hideTooltip(tooltipEl: HTMLDivElement) {
    tooltipEl.style.opacity = '0';
    tooltipEl.style.visibility = 'hidden';
  }

  private resetTooltipPosition(tooltipEl: HTMLDivElement) {
    tooltipEl.style.opacity = '0';
    tooltipEl.style.visibility = 'hidden';
    tooltipEl.style.left = '0px';
    tooltipEl.style.top = '0px';
  }

  private normalizeTitle(title?: string | string[]): string | undefined {
    if (!title) return;
    if (Array.isArray(title)) return title.filter(Boolean).join(' ');
    return title;
  }

  private renderRow(item: TooltipItem, useKilo: boolean): string {
    const value = item.dp.parsed.y;
    if (value == null) return '';

    const label = this.escapeHtml(String(item.dp.dataset.label ?? ''));
    const formattedValue = this.escapeHtml(this.formatValue(value, useKilo));
    const bgColor = item.color?.backgroundColor;
    const brdColor = item.color?.borderColor;
    const backgroundColor =
      typeof bgColor === 'string' ? bgColor : 'transparent';
    const borderColor = typeof brdColor === 'string' ? brdColor : 'transparent';

    return `
      <div class="chart-tooltip-row">
        <div class="chart-tooltip-label">
          <span class="chart-tooltip-color" style="background:${backgroundColor};border-color:${borderColor};"></span>
          <span class="chart-tooltip-name">${label}</span>
        </div>
        <div class="chart-tooltip-value">${formattedValue}</div>
      </div>
    `;
  }

  private escapeHtml(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }
}

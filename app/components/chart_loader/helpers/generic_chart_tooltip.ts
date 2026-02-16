// Renders and positions a custom HTML tooltip for non-power-balance charts.
import type { Chart, Color } from 'chart.js';

import {
  colorToString,
  createTooltipElement,
  escapeHtml,
  hideTooltip,
  positionTooltipElement,
} from './tooltip_utils';

type TooltipBody = {
  before: string[];
  lines: string[];
  after: string[];
};

type TooltipModel = {
  opacity: number;
  title: string[];
  body: TooltipBody[];
  footer: string[];
  labelColors: Array<{ backgroundColor: Color; borderColor: Color }>;
  caretX: number;
  options: { displayColors?: unknown };
};

type TooltipContext = {
  chart: Chart;
  tooltip: TooltipModel;
};

// Custom HTML tooltip renderer for generic (non-power-balance) charts.
export default class GenericChartTooltip {
  private tooltip?: HTMLDivElement;

  destroy() {
    this.tooltip?.remove();
    this.tooltip = undefined;
  }

  render(context: TooltipContext) {
    const { chart, tooltip } = context;
    const tooltipEl = this.getTooltipElement();

    if (!tooltip || tooltip.opacity === 0) {
      return hideTooltip(tooltipEl);
    }

    const body = tooltip.body ?? [];
    if (!body.length) return hideTooltip(tooltipEl);

    const contentEl = tooltipEl.querySelector(
      '.chart-tooltip-content',
    ) as HTMLElement;
    contentEl.innerHTML = this.buildHtml(tooltip);

    this.positionTooltip(tooltipEl, chart, tooltip);
  }

  private getTooltipElement(): HTMLDivElement {
    if (this.tooltip) return this.tooltip;

    this.tooltip = createTooltipElement();
    return this.tooltip;
  }

  private buildHtml(tooltip: TooltipModel): string {
    const titleHtml = this.renderTitle(tooltip.title);
    const bodyHtml = this.renderBody(tooltip);
    const footerHtml = this.renderFooter(tooltip.footer);

    return `${titleHtml}${bodyHtml}${footerHtml}`;
  }

  private renderTitle(title: string[]): string {
    const text = title.filter(Boolean).join(' ');
    if (!text) return '';

    return `<div class="chart-tooltip-title">${escapeHtml(text)}</div>`;
  }

  private renderBody(tooltip: TooltipModel): string {
    const { body, labelColors, options } = tooltip;
    const showColors = options.displayColors === true;

    const allLines = body.flatMap((b) => b.lines).filter(Boolean);

    // Single value without label: render as plain text
    if (allLines.length === 1 && !allLines[0].includes(': ')) {
      return `<div class="chart-tooltip-single">${escapeHtml(allLines[0])}</div>`;
    }

    const rows = body
      .flatMap((bodyItem, index) => {
        const color = labelColors[index];
        return bodyItem.lines.map((line, lineIndex) =>
          this.renderRow(line, showColors ? color : undefined, lineIndex > 0),
        );
      })
      .join('');

    if (!rows) return '';

    return `<div class="chart-tooltip-group">${rows}</div>`;
  }

  private renderRow(
    line: string,
    color: { backgroundColor: Color; borderColor: Color } | undefined,
    isSubsequentLine: boolean,
  ): string {
    if (!line) return '';

    const { label, value } = this.splitLabelValue(line);

    const colorHtml =
      color && !isSubsequentLine
        ? `<span class="chart-tooltip-color" style="background:${colorToString(color.backgroundColor)};"></span>`
        : color && isSubsequentLine
          ? '<span class="chart-tooltip-color" style="background:transparent;border-color:transparent;"></span>'
          : '';

    const labelHtml = label
      ? `<div class="chart-tooltip-label">${colorHtml}<span class="chart-tooltip-name">${escapeHtml(label)}</span></div>`
      : colorHtml
        ? `<div class="chart-tooltip-label">${colorHtml}</div>`
        : '';

    return `
      <div class="chart-tooltip-row">
        ${labelHtml}
        <div class="chart-tooltip-value">${escapeHtml(value)}</div>
      </div>
    `;
  }

  private renderFooter(footer: string[]): string {
    const lines = footer.filter(Boolean);
    if (!lines.length) return '';

    const footerRows = lines
      .map(
        (line) => `<div class="chart-tooltip-footer">${escapeHtml(line)}</div>`,
      )
      .join('');

    return `<div class="chart-tooltip-separator"></div>${footerRows}`;
  }

  private splitLabelValue(line: string): {
    label: string | null;
    value: string;
  } {
    const colonIndex = line.indexOf(': ');
    if (colonIndex === -1) return { label: null, value: line };

    return {
      label: line.substring(0, colonIndex),
      value: line.substring(colonIndex + 2),
    };
  }

  private positionTooltip(
    tooltipEl: HTMLDivElement,
    chart: Chart,
    tooltip: TooltipModel,
  ) {
    const canvasRect = chart.canvas.getBoundingClientRect();
    const centerY =
      canvasRect.top + (chart.chartArea.top + chart.chartArea.bottom) / 2;

    positionTooltipElement(tooltipEl, chart, tooltip.caretX, centerY);
  }
}

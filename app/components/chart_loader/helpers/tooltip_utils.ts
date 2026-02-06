// Shared utilities for tooltip renderers.
import type { Chart, Color } from 'chart.js';

export const escapeHtml = (value: string): string =>
  value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

export const colorToString = (color: Color): string =>
  typeof color === 'string' ? color : 'transparent';

export const hideTooltip = (tooltipEl: HTMLDivElement): void => {
  tooltipEl.style.opacity = '0';
  tooltipEl.style.visibility = 'hidden';
};

export const showTooltip = (
  tooltipEl: HTMLDivElement,
  left: number,
  top: number,
): void => {
  tooltipEl.style.left = `${left}px`;
  tooltipEl.style.top = `${top}px`;
  tooltipEl.style.opacity = '1';
  tooltipEl.style.visibility = 'visible';
};

export const createTooltipElement = (
  ...classNames: string[]
): HTMLDivElement => {
  const tooltipEl = document.createElement('div');
  tooltipEl.className = ['chartjs-tooltip', ...classNames].join(' ');

  const contentEl = document.createElement('div');
  contentEl.className = 'chart-tooltip-content';
  tooltipEl.appendChild(contentEl);

  document.body.appendChild(tooltipEl);
  return tooltipEl;
};

// Positions a tooltip element relative to the chart, handling mobile/desktop
// layout and viewport clamping. desktopCenterY is the viewport-relative Y
// position around which the tooltip is vertically centered on desktop.
// All coordinates are viewport-relative (matching position: fixed).
export const positionTooltipElement = (
  tooltipEl: HTMLDivElement,
  chart: Chart,
  caretX: number,
  desktopCenterY: number,
): void => {
  const canvasRect = chart.canvas.getBoundingClientRect();
  const tooltipWidth = tooltipEl.offsetWidth;
  const tooltipHeight = tooltipEl.offsetHeight;
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  const margin = 12;
  const isMobileViewport = window.matchMedia('(max-width: 639px)').matches;

  // canvasRect is viewport-relative (from getBoundingClientRect),
  // matching position: fixed — no scroll offset needed.
  const absoluteCaretX = canvasRect.left + caretX;

  // Horizontal: on mobile center on caret, otherwise left/right of crosshair
  let left = 0;
  if (isMobileViewport) {
    left = absoluteCaretX - tooltipWidth / 2;
  } else {
    const spaceLeft = caretX - chart.chartArea.left;
    const spaceRight = chart.chartArea.right - caretX;
    const preferRight = spaceRight >= spaceLeft;
    left = preferRight
      ? absoluteCaretX + margin
      : absoluteCaretX - tooltipWidth - margin;
  }

  if (left < margin) left = margin;
  const maxLeft = viewportWidth - tooltipWidth - margin;
  if (left > maxLeft) left = maxLeft;

  // Vertical: on mobile above chart, otherwise centered on desktopCenterY
  let top = isMobileViewport
    ? canvasRect.top - tooltipHeight - margin
    : desktopCenterY - tooltipHeight / 2;
  if (top < margin) top = margin;
  const maxTop = viewportHeight - tooltipHeight - margin;
  if (top > maxTop) top = maxTop;

  showTooltip(tooltipEl, left, top);
};

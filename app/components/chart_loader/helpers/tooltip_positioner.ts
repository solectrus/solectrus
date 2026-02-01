// Registers a tooltip positioner that pins to the chart bottom.
import { Chart, Tooltip } from 'chart.js';

type TooltipPositioner = typeof Tooltip.positioners.nearest;
type TooltipPositioners = typeof Tooltip.positioners &
  Record<string, TooltipPositioner>;
type ChartWithTooltip = typeof Chart & { Tooltip?: typeof Tooltip };

const registerTooltipPositioner = (
  name: string,
  positioner: TooltipPositioner,
): void => {
  (Tooltip.positioners as TooltipPositioners)[name] = positioner;
  const chartTooltip = (Chart as ChartWithTooltip).Tooltip;
  if (chartTooltip?.positioners) {
    (chartTooltip.positioners as TooltipPositioners)[name] = positioner;
  }
};

// Registers a tooltip positioner that pins tooltips to the chart bottom.
export const ensureFixedBottomTooltipPositioner = (
  offset: number = -14,
): void => {
  if ('fixedBottom' in Tooltip.positioners) return;

  const fixedBottom: TooltipPositioner = function (items, eventPosition) {
    if (!items.length) return false;
    const position = Tooltip.positioners.nearest.call(
      this,
      items,
      eventPosition,
    );
    if (!position || position.x == null || position.y == null) return false;

    const chart =
      this.chart ?? (items[0]?.element as { chart?: Chart } | undefined)?.chart;
    const bottom = chart?.chartArea?.bottom ?? 0;

    return { x: position.x, y: bottom + offset };
  };

  registerTooltipPositioner('fixedBottom', fixedBottom);
};

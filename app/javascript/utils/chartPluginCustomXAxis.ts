import { Chart, Plugin, Scale, Tick } from 'chart.js';

// Constants for responsive design
const TAILWIND_MD_BREAKPOINT = 768;
const CHART_BOTTOM_MARGIN = 10;
const DEFAULT_LINE_OFFSET_Y = 14;
const DEFAULT_FONT = '14px Inter Variable, sans-serif';
const DEFAULT_COLOR = '#6b7280';

interface LineConfig {
  text?: string;
  font?: string;
  color?: string;
  offsetY?: number;
  md?: {
    text: string;
    font?: string;
    color?: string;
    offsetY?: number;
  } | null;
}

interface LabelData {
  x: number;
  lines: LineConfig[];
}

interface CustomLabelsConfig {
  enabled: boolean;
  labels: LabelData[];
}

interface ScaleWithTicks extends Scale {
  ticks: Tick[];
}

/**
 * Creates a custom plugin for Chart.js that renders custom X-axis labels
 * with support for responsive text variants (small vs medium+ screens).
 *
 * Features:
 * - Custom tick positions on x-axis
 * - Responsive label variants (md breakpoint at 768px)
 * - Per-label styling (font, color, offset)
 * - Option to hide labels on larger screens (md: null)
 *
 * @param options - Chart options object containing customXAxisLabels config
 * @returns Array with custom plugin or empty array if disabled
 */
export function buildCustomXAxisPlugin(
  options: Record<string, unknown>,
): Plugin[] {
  const scales = options.scales as Record<string, unknown> | undefined;
  const xScale = scales?.x as Record<string, unknown> | undefined;
  const pluginsConfig = options.plugins as Record<string, unknown> | undefined;
  const customLabels = pluginsConfig?.customXAxisLabels as
    | CustomLabelsConfig
    | undefined;

  if (!customLabels?.enabled || !customLabels.labels?.length) return [];

  // Setup custom tick positions on x-axis
  if (xScale?.customTickPositions) {
    const positions = xScale.customTickPositions as number[];
    xScale.afterBuildTicks = (scale: ScaleWithTicks) => {
      scale.ticks = positions.map((value) => ({ value }));
    };
    delete xScale.customTickPositions;

    const ticks = xScale.ticks as Record<string, unknown> | undefined;
    if (ticks) ticks.callback = () => ''; // Hide default tick labels
  }

  return [
    {
      id: 'customXAxisLabels',
      beforeDraw: (chart: Chart) => {
        const { ctx, scales, chartArea } = chart;
        if (!scales.x || !chartArea) return;

        ctx.save();
        ctx.textAlign = 'center';

        // Check screen size on each draw (Chart.js caches and only redraws on changes)
        const isMediumOrLarger =
          globalThis.innerWidth >= TAILWIND_MD_BREAKPOINT;

        for (const { x, lines } of customLabels.labels) {
          const xPos = scales.x.getPixelForValue(x);
          const yStart = chartArea.bottom + CHART_BOTTOM_MARGIN;

          for (const line of lines) {
            // On medium+ screens: use md variant if provided, skip if null
            if (isMediumOrLarger && line.md === null) continue;

            const config = isMediumOrLarger ? (line.md ?? line) : line;
            if (!config?.text) continue;

            ctx.font = config.font || DEFAULT_FONT;
            ctx.fillStyle = config.color || DEFAULT_COLOR;
            ctx.fillText(
              config.text,
              xPos,
              yStart + (config.offsetY ?? DEFAULT_LINE_OFFSET_Y),
            );
          }
        }

        ctx.restore();
      },
    },
  ];
}

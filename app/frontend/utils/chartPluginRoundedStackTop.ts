import { BarElement, Chart, Plugin } from 'chart.js';

// Minimum corner radius applied to every bar-stack top, even when the bars
// themselves carry no (or a zero) borderRadius.
const DEFAULT_RADIUS = 3;

// Two towers of the same period whose edges are this close (px) count as glued
// into one visual unit -- e.g. the power-splitter's main bar and its PV/grid
// split are sized to touch exactly. Only the unit's outer corners get rounded.
const MERGE_GAP = 2;

// Skip rounding entirely on charts with more columns than this. Beyond it the
// bars get too thin for the corner radius to show (e.g. 365 daily columns are a
// few px wide), while the per-bar-dataset clip below would run once per bar
// dataset every frame -- wasted work on exactly the densest charts. Months
// (<=31 columns) and shorter still round.
const MAX_ROUNDED_COLUMNS = 31;

type Tower = { left: number; right: number; top: number };

// Chart.js only rounds the topmost segment of a stacked bar (the highest
// dataset with value > 0, see BarController). When a thin segment caps a large
// one, its radius collapses to the segment height and the dominant segment
// below renders a flat top -- so some columns look un-rounded. Per-dataset
// borderRadius also can't round a composite stack whose top segment is
// configured flat (e.g. the power-splitter charts).
//
// This plugin is stack-agnostic: before the bars draw it groups every bar of a
// column by its geometry (same center + width = one visual tower, regardless of
// stack key) and clips each tower to a rounded-top rectangle. Towers of the
// same period that touch are merged so only the outer corners round (the glued
// seam between them stays square). The composite top is then always rounded, no
// matter which segment sits on top or how the datasets are configured.
export function buildRoundedStackTopPlugin(): Plugin {
  return {
    id: 'roundedStackTop',
    // Clip per bar dataset, not around the whole datasets-draw phase: a phase-
    // wide clip (beforeDatasetsDraw) also clips line datasets drawn in the same
    // phase -- e.g. the forecast temperature curve -- down to the thin bar
    // columns, hiding them.
    beforeDatasetDraw(chart: Chart, args: { meta: { type: string } }) {
      if (args.meta.type !== 'bar') return;
      if ((chart.data.labels?.length ?? 0) > MAX_ROUNDED_COLUMNS) return;

      const { ctx, chartArea } = chart;
      // Save unconditionally so afterDatasetDraw can restore unconditionally --
      // save/restore stay balanced even when there is nothing to clip.
      ctx.save();

      // Bucket upward bar segments into towers, grouped per period (column). Bars
      // of a column sharing a center and width stack into one tower; the highest
      // (smallest y) segment sets its top.
      const columns = new Map<number, Tower[]>();

      // One radius for the whole chart (the largest any bar asks for, floored at
      // the default) so every tower rounds identically -- mismatched radii on
      // adjacent bars would look off. Using the max also keeps the clip from
      // ever being tighter than a bar's own rounding, which would carve a
      // transparent notch out of its corner.
      let radius = DEFAULT_RADIUS;

      for (const meta of chart.getSortedVisibleDatasetMetas()) {
        if (meta.type !== 'bar') continue;

        meta.data.forEach((element, index) => {
          const bar = element as BarElement;
          const { x, y, base, width } = bar.getProps(
            ['x', 'y', 'base', 'width'],
            true,
          );
          if (x == null || y == null || base == null || width == null) return;
          // Only upward, non-empty segments contribute: a null or non-positive
          // segment has its head on the base, so it adds no height.
          if (base - y <= 0) return;

          radius = Math.max(radius, topRadius(bar));

          const left = x - width / 2;
          const right = x + width / 2;
          let list = columns.get(index);
          if (!list) {
            list = [];
            columns.set(index, list);
          }
          const tower = list.find(
            (t) =>
              Math.round(t.left) === Math.round(left) &&
              Math.round(t.right) === Math.round(right),
          );
          if (tower) tower.top = Math.min(tower.top, y);
          else list.push({ left, right, top: y });
        });
      }

      if (!columns.size) return;

      const bottom = chartArea.bottom;
      ctx.beginPath();

      for (const list of columns.values()) {
        list.sort((a, b) => a.left - b.left);

        list.forEach((tower, i) => {
          const width = tower.right - tower.left;
          const height = bottom - tower.top;
          const limit = Math.min(width / 2, height / 2);
          const r = Math.max(0, Math.min(radius, limit));
          // Towers close enough to touch merge into one visual unit: the shared
          // seam stays square, only the unit's outer top corners round.
          const touchesLeft =
            i > 0 && tower.left - list[i - 1].right <= MERGE_GAP;
          const touchesRight =
            i < list.length - 1 && list[i + 1].left - tower.right <= MERGE_GAP;
          ctx.roundRect(tower.left, tower.top, width, height, [
            touchesLeft ? 0 : r,
            touchesRight ? 0 : r,
            0,
            0,
          ]);
        });
      }

      ctx.clip();
    },
    afterDatasetDraw(chart: Chart, args: { meta: { type: string } }) {
      if (args.meta.type !== 'bar') return;
      if ((chart.data.labels?.length ?? 0) > MAX_ROUNDED_COLUMNS) return;

      chart.ctx.restore();
    },
  };
}

// Largest top-corner radius a bar asks for (number or per-corner object).
function topRadius(bar: BarElement): number {
  const value = bar.options?.borderRadius;
  if (typeof value === 'number') return value;
  if (value && typeof value === 'object')
    return Math.max(value.topLeft ?? 0, value.topRight ?? 0);
  return 0;
}

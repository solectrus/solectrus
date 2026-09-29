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

type Tower = { left: number; right: number; top: number; bottom: number };

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

      const { ctx } = chart;
      // Save unconditionally so afterDatasetDraw can restore unconditionally --
      // save/restore stay balanced even when there is nothing to clip.
      ctx.save();
      ctx.beginPath();

      // Bucket bar segments into towers, grouped per period (column) and
      // direction. Bars of a column sharing a center and width stack into one
      // tower; the outermost segment sets its rounded end.
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
          // A null segment has its head on the base, so it adds no height.
          if (y === base) return;

          radius = Math.max(radius, topRadius(bar));

          const left = x - width / 2;
          const right = x + width / 2;
          const top = Math.min(y, base);
          const bottom = Math.max(y, base);
          // Downward segments (a negated series, e.g. the usage stack of the
          // power balance) form their own towers, which round at the bottom.
          // The key ~index keeps them apart from the upward ones.
          const key = y > base ? ~index : index;
          let list = columns.get(key);
          if (!list) {
            list = [];
            columns.set(key, list);
          }
          const tower = list.find(
            (t) =>
              Math.round(t.left) === Math.round(left) &&
              Math.round(t.right) === Math.round(right),
          );
          if (tower) {
            tower.top = Math.min(tower.top, top);
            tower.bottom = Math.max(tower.bottom, bottom);
          } else list.push({ left, right, top, bottom });
        });
      }

      if (!columns.size) return;

      for (const [key, list] of columns) {
        list.sort((a, b) => a.left - b.left);

        list.forEach((tower, i) => {
          const width = tower.right - tower.left;
          const height = tower.bottom - tower.top;
          const limit = Math.min(width / 2, height / 2);
          const r = Math.max(0, Math.min(radius, limit));
          // Towers close enough to touch merge into one visual unit: the shared
          // seam stays square, only the unit's outer corners round.
          const touchesLeft =
            i > 0 && tower.left - list[i - 1].right <= MERGE_GAP;
          const touchesRight =
            i < list.length - 1 && list[i + 1].left - tower.right <= MERGE_GAP;
          const rl = touchesLeft ? 0 : r;
          const rr = touchesRight ? 0 : r;
          // Corners: top-left, top-right, bottom-right, bottom-left.
          ctx.roundRect(
            tower.left,
            tower.top,
            width,
            height,
            key < 0 ? [0, 0, rr, rl] : [rl, rr, 0, 0],
          );
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

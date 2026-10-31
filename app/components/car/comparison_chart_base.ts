import { Controller } from '@hotwired/stimulus';
import type { Chart, ChartType, Scale } from 'chart.js';
import { isReducedMotion } from '@/utils/device';
import { appLocale } from '@/utils/locale';

import {
  getAxisColors,
  type AxisColors,
} from '../chart_loader/helpers/axis_styles';
import GenericChartTooltip from '../chart_loader/helpers/generic_chart_tooltip';

// The width of the y axis of the two charts of the comparison with a
// combustion car (the periods and the weeks). The same width puts their
// plot areas one above the other, so a week stands under the bars of its
// period. It holds an amount like "-10.000 €".
export const Y_AXIS_WIDTH = 64;

export const fixYAxisWidth = (axis: Scale): void => {
  axis.width = Y_AXIS_WIDTH;
};

// The options of chartjs-plugin-crosshair, whose key is unknown to the
// Chart.js types
export const crosshair = (options: unknown) =>
  ({ crosshair: options }) as unknown as Record<string, never>;

// The colors of the columns of the comparison, from the hidden dots
export const swatchColors = (swatches: HTMLElement[]): string[] =>
  swatches.map((swatch) => window.getComputedStyle(swatch).backgroundColor);

// A series of a chart of the columns (see Car::ComparisonFormat#column_series):
// the key names the column, and the suffix follows the label of the car
// beside the car without PV
export interface ColumnSeries {
  key: string;
  label: string;
  suffix?: string;
  values: number[];
}

// Whether the page shows the car without PV (see
// car/comparison_page/component_controller.ts)
export const showsWithoutPv = (element: HTMLElement): boolean =>
  element.closest('[data-without-pv]') !== null;

// The car without PV hides until the page shows it
export const seriesHidden = (series: ColumnSeries, withoutPv: boolean) =>
  !withoutPv && series.key === 'without_pv';

// Beside the car without PV, the car adds the suffix of its title
export const seriesLabel = (series: ColumnSeries, withoutPv: boolean) =>
  withoutPv && series.suffix
    ? `${series.label} ${series.suffix}`
    : series.label;

// The charts of the comparison with a combustion car (see
// Car::ComparisonChart, Car::ComparisonRateChart and Car::FuelPriceChart).
// Each reads its data from a JSON script and builds its chart in #process.
// The colors come from CSS. The chart keeps them until a new theme, which
// builds a new chart.
export default abstract class ComparisonChartBase<
  TData,
  TType extends ChartType,
> extends Controller<HTMLElement> {
  declare readonly canvasTarget: HTMLCanvasElement;
  declare readonly dataTarget: HTMLScriptElement;
  declare currencyValue: string;

  protected chart?: Chart<TType>;
  private tooltip?: GenericChartTooltip;
  private moneyFormatters: Record<number, Intl.NumberFormat> = {};
  private colorCache = new Map<string, unknown>();
  private boundRebuild = () => {
    this.colorCache.clear();
    this.rebuild();
  };

  connect() {
    this.process();
    document.addEventListener('theme:changed', this.boundRebuild);
  }

  disconnect() {
    document.removeEventListener('theme:changed', this.boundRebuild);

    this.chart?.destroy();
    this.tooltip?.destroy();
    this.tooltip = undefined;
  }

  protected abstract process(options?: { animate?: boolean }): void;

  protected rebuild() {
    this.chart?.destroy();
    this.process({ animate: false });
  }

  // A color from CSS, read once until a new theme
  protected cachedColor<T>(key: string, read: () => T): T {
    if (!this.colorCache.has(key)) this.colorCache.set(key, read());
    return this.colorCache.get(key) as T;
  }

  protected getData(): TData | undefined {
    if (this.dataTarget.textContent)
      return JSON.parse(this.dataTarget.textContent);
  }

  protected getTooltip(): GenericChartTooltip {
    this.tooltip ??= new GenericChartTooltip();
    return this.tooltip;
  }

  protected axisColors(): AxisColors {
    return this.cachedColor('axis', () => {
      const rootStyle = window.getComputedStyle(document.documentElement);
      return getAxisColors((name) => rootStyle.getPropertyValue(name).trim());
    });
  }

  protected animation(animate: boolean) {
    return isReducedMotion() || !animate
      ? false
      : { duration: 600, easing: 'easeOutQuart' as const };
  }

  // The title in the text color of the page. It stands at the left, apart
  // from the centered button of the details above the charts.
  protected titleOptions(text: string) {
    return {
      display: true,
      text,
      align: 'start' as const,
      color: this.cachedColor(
        'title',
        () => window.getComputedStyle(this.element).color,
      ),
      font: { size: 16, weight: 600 },
      padding: { bottom: 4 },
    };
  }

  // An amount with `digits` decimals
  protected formatMoney(value: number, digits: number): string {
    const formatter = (this.moneyFormatters[digits] ??= new Intl.NumberFormat(
      appLocale(),
      {
        style: 'currency',
        currency: this.currencyValue,
        minimumFractionDigits: digits,
        maximumFractionDigits: digits,
      },
    ));
    return formatter.format(value);
  }
}

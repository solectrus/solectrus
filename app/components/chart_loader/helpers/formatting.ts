// Number and interval formatting for axes and tooltips.
import type { Range } from './types';

type FormatTarget = 'axis' | 'tooltip';

type FormatOptions = {
  target?: FormatTarget;
  autoKilo?: boolean;
  unitValue: string;
  currency: string;
  locale: string;
  range: Range;
};

// Determines min/max decimal places based on target, unit, and range.
export const getDecimalPlaces = (
  target: FormatTarget,
  kilo: boolean,
  isCurrency: boolean,
  unitValue: string,
  { min, max }: Range,
): { minDecimals: number; maxDecimals: number } => {
  if (kilo) {
    // Decide from the largest value of the range, so all lines in a tooltip
    // share the same precision. Above 100 kWh the fractional digit is just
    // noise (e.g. 523,7 kWh), so drop it; keep it for smaller values.
    const kiloMax = Math.max(Math.abs(min), Math.abs(max)) / 1000;
    const maxDecimals = kiloMax >= 100 ? 0 : 1;
    return { minDecimals: 0, maxDecimals };
  }

  if (isCurrency) {
    const showDecimals = target === 'axis' ? max < 10 : min < 10 && max < 100;
    const decimals = showDecimals ? 2 : 0;
    return { minDecimals: decimals, maxDecimals: decimals };
  }

  const maxDecimals = unitValue === '' || unitValue === '°C' ? 1 : 0;
  return { minDecimals: 0, maxDecimals };
};

// Tooltip callbacks fire on every mouse move, once per dataset. Reuse the
// formatters instead of allocating a new Intl.NumberFormat per hover; the key
// space is one locale times a handful of decimal combinations.
const numberFormatters = new Map<string, Intl.NumberFormat>();

export const numberFormatter = (
  locale: string,
  minimumFractionDigits: number,
  maximumFractionDigits: number,
): Intl.NumberFormat => {
  const key = `${locale}|${minimumFractionDigits}|${maximumFractionDigits}`;

  let formatter = numberFormatters.get(key);
  if (!formatter) {
    formatter = new Intl.NumberFormat(locale, {
      minimumFractionDigits,
      maximumFractionDigits,
    });
    numberFormatters.set(key, formatter);
  }

  return formatter;
};

// The tooltip title is built on the same renders, so its date formatters are
// cached the same way. The styles are named instead of passed as options, so
// the key space stays one locale times the styles listed here.
const dateTimeStyles = {
  time: { hour: '2-digit', minute: '2-digit' },
  date: { day: '2-digit', month: '2-digit', year: 'numeric' },
} as const satisfies Record<string, Intl.DateTimeFormatOptions>;

export type DateTimeStyle = keyof typeof dateTimeStyles;

const dateTimeFormatters = new Map<string, Intl.DateTimeFormat>();

export const dateTimeFormatter = (
  locale: string,
  style: DateTimeStyle,
): Intl.DateTimeFormat => {
  const key = `${locale}|${style}`;

  let formatter = dateTimeFormatters.get(key);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat(locale, dateTimeStyles[style]);
    dateTimeFormatters.set(key, formatter);
  }

  return formatter;
};

type ScaleOptions = Omit<FormatOptions, 'locale'>;

const numberScale = ({
  target = 'tooltip',
  autoKilo = true,
  unitValue,
  currency,
  range,
}: ScaleOptions) => {
  const isCurrency = currency !== '' && unitValue.includes(currency);

  // Decide the kilo prefix from the range, not per value, so everything that
  // is shown together shares one unit (e.g. all kWh, never a mix of "48 kWh"
  // and "464 Wh").
  const kilo =
    autoKilo && !isCurrency && (range.max > 1000 || range.min < -1000);

  return {
    kilo,
    ...getDecimalPlaces(target, kilo, isCurrency, unitValue, range),
  };
};

// Decimals of the raw value that formatNumber keeps: 2 for "5,83 €", -2 for
// "3,5 kWh" printed from Wh
export const roundingDigits = (options: ScaleOptions): number => {
  const { kilo, maxDecimals } = numberScale(options);

  return kilo ? maxDecimals - 3 : maxDecimals;
};

// Formats a number for axis or tooltip display, optionally applying kilo units.
export const formatNumber = (
  number: number,
  { locale, ...options }: FormatOptions,
): string => {
  const { kilo, minDecimals, maxDecimals } = numberScale(options);

  const numberAsString = numberFormatter(
    locale,
    minDecimals,
    maxDecimals,
  ).format(kilo ? number / 1000.0 : number);

  return `${numberAsString} ${kilo ? 'k' : ''}${options.unitValue}`;
};

// Formats a min/max interval using a shared formatter.
export const formatInterval = (
  min: number,
  max: number,
  formatter: (value: number) => string,
): string => {
  const formattedMin = formatter(min);
  const formattedMax = formatter(max);

  return formattedMin === formattedMax
    ? formattedMin
    : `${formattedMin} - ${formattedMax}`;
};

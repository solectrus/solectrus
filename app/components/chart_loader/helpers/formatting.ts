// Number and interval formatting for axes and tooltips.
type FormatTarget = 'axis' | 'tooltip';

type FormatOptions = {
  target?: FormatTarget;
  autoKilo?: boolean;
  unitValue: string;
  locale: string;
  minValue: number;
  maxValue: number;
};

// Determines min/max decimal places based on target, unit, and range.
export const getDecimalPlaces = (
  target: FormatTarget,
  kilo: boolean,
  isEuro: boolean,
  unitValue: string,
  minValue: number,
  maxValue: number,
): { minDecimals: number; maxDecimals: number } => {
  if (kilo) {
    // Decide chart-wide from the largest value, so all lines in a tooltip
    // share the same precision. Above 100 kWh the fractional digit is just
    // noise (e.g. 523,7 kWh), so drop it; keep it for smaller values.
    const kiloMax = Math.max(Math.abs(minValue), Math.abs(maxValue)) / 1000;
    const maxDecimals = kiloMax >= 100 ? 0 : 1;
    return { minDecimals: 0, maxDecimals };
  }

  if (isEuro) {
    const showDecimals =
      target === 'axis' ? maxValue < 10 : minValue < 10 && maxValue < 100;
    const decimals = showDecimals ? 2 : 0;
    return { minDecimals: decimals, maxDecimals: decimals };
  }

  const maxDecimals = unitValue === '' || unitValue === '°C' ? 1 : 0;
  return { minDecimals: 0, maxDecimals };
};

// Formats a number for axis or tooltip display, optionally applying kilo units.
export const formatNumber = (
  number: number,
  {
    target = 'tooltip',
    autoKilo = true,
    unitValue,
    locale,
    minValue,
    maxValue,
  }: FormatOptions,
): string => {
  let unitValuePrefix = '';
  const isEuro = unitValue.includes('€');

  // Decide the kilo prefix chart-wide from the axis range (not per value), so
  // every tooltip line and axis tick shares the same unit (e.g. all kWh, never
  // a mix of "48 kWh" and "464 Wh").
  const kilo = autoKilo && !isEuro && (maxValue > 1000 || minValue < -1000);
  if (kilo) {
    number /= 1000.0;
    unitValuePrefix = 'k';
  }

  const { minDecimals, maxDecimals } = getDecimalPlaces(
    target,
    kilo,
    isEuro,
    unitValue,
    minValue,
    maxValue,
  );

  const numberAsString = new Intl.NumberFormat(locale, {
    minimumFractionDigits: minDecimals,
    maximumFractionDigits: maxDecimals,
  }).format(number);

  return `${numberAsString} ${unitValuePrefix}${unitValue}`;
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

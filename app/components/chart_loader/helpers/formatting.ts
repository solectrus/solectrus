// Number and interval formatting for axes and tooltips.
type FormatTarget = 'axis' | 'tooltip';

type FormatOptions = {
  target?: FormatTarget;
  autoKilo?: boolean;
  unitValue: string;
  currency: string;
  locale: string;
  minValue: number;
  maxValue: number;
};

// Determines min/max decimal places based on target, unit, and range.
export const getDecimalPlaces = (
  target: FormatTarget,
  kilo: boolean,
  isCurrency: boolean,
  unitValue: string,
  minValue: number,
  maxValue: number,
): { minDecimals: number; maxDecimals: number } => {
  if (kilo) {
    const maxDecimals = 1;
    return { minDecimals: 0, maxDecimals };
  }

  if (isCurrency) {
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
    currency,
    locale,
    minValue,
    maxValue,
  }: FormatOptions,
): string => {
  let unitValuePrefix = '';
  const isCurrency = currency !== '' && unitValue.includes(currency);

  const kilo =
    autoKilo &&
    !isCurrency &&
    (target === 'axis'
      ? maxValue > 1000 || minValue < -1000
      : number > 1000 || number < -1000);
  if (kilo) {
    number /= 1000.0;
    unitValuePrefix = 'k';
  }

  const { minDecimals, maxDecimals } = getDecimalPlaces(
    target,
    kilo,
    isCurrency,
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

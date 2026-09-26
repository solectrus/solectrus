// Rounds the values of a chart tooltip, so they add up like the tooltips
// rendered on the server (RoundedSum). The rule differs: the server rounds all
// parts but the last as usual, and the last one takes the rest. A stack can
// hold many parts, so here the rounding spreads over all of them instead of
// loading it onto the last one. The same values can thus round differently in
// a chart and in a card: 0,4 + 0,4 + 0,4 shows as 1 + 0 + 0 here, as
// 0 + 0 + 1 there.

const total = (values: number[]): number =>
  values.reduce((sum, value) => sum + value, 0);

// Half away from zero, like Ruby and Intl.NumberFormat: -2.5 is -3, not -2.
// Adding 0 turns -0 into 0, which Intl would print as "-0".
const round = (value: number): number =>
  Math.sign(value) * Math.round(Math.abs(value)) + 0;

// Float noise must not shift a value across a unit (1.005 * 100 = 100.49999999999999)
const scale = (value: number, digits: number): number =>
  Number((value * 10 ** digits).toFixed(6)) + 0;

// Largest remainder method: all parts are rounded down, and the units still
// missing to the target go to the parts with the largest remainders. Every
// part thus shows its own value, rounded down or up, so a 0 stays 0. Returns
// nothing when no such choice reaches the target.
const largestRemainder = (
  scaled: number[],
  target: number,
): number[] | undefined => {
  const rounded = scaled.map(Math.floor);
  const missing = target - total(rounded);
  const fractions = scaled
    .map((value, index) => ({ index, remainder: value - rounded[index] }))
    .filter(({ remainder }) => remainder > 0);
  if (missing < 0 || missing > fractions.length) return;

  fractions
    .sort((a, b) => b.remainder - a.remainder)
    .slice(0, missing)
    .forEach(({ index }) => (rounded[index] += 1));

  return rounded;
};

// A sum with its parts, rounded to the same digits, so the parts add up to the
// sum as shown. The sum may come from elsewhere (a total dataset), so it keeps
// its value, and the parts spread its rounding among them. A negative number
// of digits rounds to tens, hundreds and so on.
//
// A sum the parts cannot reach by rounding is a real difference, which no
// part may hide, so each value then rounds on its own.
export const roundedSum = (
  parts: number[],
  sum: number,
  digits: number,
): { parts: number[]; sum: number } => {
  const scaled = parts.map((part) => scale(part, digits));
  const target = round(scale(sum, digits));
  const rounded = largestRemainder(scaled, target) ?? scaled.map(round);

  return {
    parts: rounded.map((value) => value / 10 ** digits),
    sum: target / 10 ** digits,
  };
};

// Rounds the parts of a sum, so the rounded parts add up to the rounded sum
export const roundedParts = (amounts: number[], digits = 0): number[] =>
  roundedSum(amounts, total(amounts), digits).parts;

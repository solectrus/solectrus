export type RgbColor = {
  r: number;
  g: number;
  b: number;
  a?: number;
};

const RGB_REGEX = /^rgba?\((.*)\)$/i;

export function resolveColor(color?: string): string | undefined {
  if (!color) return;
  const rgb = parseColor(color);
  if (!rgb) return;

  if (rgb.a === undefined || rgb.a >= 1) {
    return `#${toHex(rgb.r)}${toHex(rgb.g)}${toHex(rgb.b)}`;
  }

  return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${rgb.a})`;
}

export function toRgb(color?: string): RgbColor | undefined {
  if (!color) return;
  return parseColor(color);
}

export function colorToRgba(color: string | undefined, alpha: number): string {
  if (!color) return 'rgba(0, 0, 0, 0)';
  const rgb = parseColor(color);
  if (!rgb) throw new Error(`"${color}" is not a supported color format!`);

  const clamped = Math.min(Math.max(alpha, 0), 1);
  const baseAlpha = rgb.a ?? 1;
  const finalAlpha = Math.min(Math.max(baseAlpha * clamped, 0), 1);

  return `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${finalAlpha})`;
}

export function lightenColor(
  color: string | undefined,
  amount: number,
): string | undefined {
  if (!color) return;
  const rgb = parseColor(color);
  if (!rgb) return;

  const clamped = Math.min(Math.max(amount, 0), 1);
  const r = Math.round(rgb.r + (255 - rgb.r) * clamped);
  const g = Math.round(rgb.g + (255 - rgb.g) * clamped);
  const b = Math.round(rgb.b + (255 - rgb.b) * clamped);

  if (rgb.a !== undefined && rgb.a < 1) {
    return `rgba(${r}, ${g}, ${b}, ${rgb.a})`;
  }

  return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
}

function parseColor(color: string): RgbColor | undefined {
  const trimmed = color.trim();
  const lower = trimmed.toLowerCase();

  if (lower === 'transparent') return { r: 0, g: 0, b: 0, a: 0 };

  if (/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(trimmed)) {
    const hex = trimmed.length === 4 ? expandShortHex(trimmed) : trimmed;
    return {
      r: parseInt(hex.slice(1, 3), 16),
      g: parseInt(hex.slice(3, 5), 16),
      b: parseInt(hex.slice(5, 7), 16),
    };
  }

  const rgbMatch = trimmed.match(RGB_REGEX);
  if (rgbMatch) return parseRgbParts(rgbMatch[1]);

  if (lower.startsWith('oklab(')) return parseOklab(trimmed);
  if (lower.startsWith('oklch(')) return parseOklch(trimmed);
  if (lower.startsWith('color-mix(')) return parseColorMix(trimmed);

  return;
}

function parseRgbParts(part: string): RgbColor | undefined {
  const parts = part
    .trim()
    .split(/[\s,/]+/)
    .filter(Boolean);
  if (parts.length < 3) return;

  const r = parseRgbNumber(parts[0]);
  const g = parseRgbNumber(parts[1]);
  const b = parseRgbNumber(parts[2]);
  if (r === undefined || g === undefined || b === undefined) return;

  const alpha = parts[3] ? parseAlpha(parts[3]) : undefined;
  return { r, g, b, a: alpha };
}

function parseColorMix(input: string): RgbColor | undefined {
  const match = /^color-mix\(\s*in\s+[^,]+,\s*(.+)\s*\)$/i.exec(input);
  if (!match) return;

  const parts = splitColorMixParts(match[1]);
  if (parts.length !== 2) return;

  const left = parseColorMixPart(parts[0]);
  const right = parseColorMixPart(parts[1]);
  if (!left || !right) return;

  const leftIsTransparent = left.color.toLowerCase() === 'transparent';
  const rightIsTransparent = right.color.toLowerCase() === 'transparent';
  if (leftIsTransparent === rightIsTransparent) return;

  const colorPart = leftIsTransparent ? right : left;
  const weight = colorPart.weight ?? 0.5;
  const base = parseColor(colorPart.color);
  if (!base) return;

  return { ...base, a: Math.min(Math.max(weight, 0), 1) };
}

function parseColorMixPart(
  part: string,
): { color: string; weight?: number } | undefined {
  const trimmed = part.trim();
  const match = /^(.*?)(?:\s+([0-9.]+%?))?$/.exec(trimmed);
  if (!match) return;

  const color = match[1].trim();
  if (!color) return;

  if (!match[2]) return { color };

  const weight = parseAlpha(match[2]);
  if (weight === undefined) return { color };

  return { color, weight };
}

function splitColorMixParts(input: string): string[] {
  const parts: string[] = [];
  let depth = 0;
  let current = '';

  for (const char of input) {
    if (char === '(') depth += 1;
    if (char === ')') depth = Math.max(depth - 1, 0);
    if (char === ',' && depth === 0) {
      parts.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  if (current) parts.push(current);

  return parts.map((part) => part.trim()).filter(Boolean);
}

function parseOklch(input: string): RgbColor | undefined {
  const match =
    /^oklch\(\s*([-+]?[0-9.]+%?)\s+([-+]?[0-9.]+)\s+([-+]?[0-9.]+)(?:\s*\/\s*([0-9.]+%?))?\s*\)$/i.exec(
      input,
    );
  if (!match) return;

  let lightness = parseFloat(match[1]);
  const chroma = parseFloat(match[2]);
  const hue = parseFloat(match[3]);
  if (Number.isNaN(lightness) || Number.isNaN(chroma) || Number.isNaN(hue))
    return;

  if (match[1].includes('%') || lightness > 1) lightness /= 100;
  const alpha = match[4] ? parseAlpha(match[4]) : undefined;

  const a = chroma * Math.cos((hue * Math.PI) / 180);
  const b = chroma * Math.sin((hue * Math.PI) / 180);
  const rgb = oklabToRgb(lightness, a, b);
  if (!rgb) return;

  return { ...rgb, a: alpha };
}

function parseOklab(input: string): RgbColor | undefined {
  const match =
    /^oklab\(\s*([-+]?[0-9.]+%?)\s+([-+]?[0-9.]+)\s+([-+]?[0-9.]+)(?:\s*\/\s*([0-9.]+%?))?\s*\)$/i.exec(
      input,
    );
  if (!match) return;

  let lightness = parseFloat(match[1]);
  const a = parseFloat(match[2]);
  const b = parseFloat(match[3]);
  if (Number.isNaN(lightness) || Number.isNaN(a) || Number.isNaN(b)) return;

  if (match[1].includes('%') || lightness > 1) lightness /= 100;
  const alpha = match[4] ? parseAlpha(match[4]) : undefined;

  const rgb = oklabToRgb(lightness, a, b);
  if (!rgb) return;

  return { ...rgb, a: alpha };
}

function oklabToRgb(
  lightness: number,
  a: number,
  b: number,
): RgbColor | undefined {
  const l = lightness + 0.3963377774 * a + 0.2158037573 * b;
  const m = lightness - 0.1055613458 * a - 0.0638541728 * b;
  const s = lightness - 0.0894841775 * a - 1.291485548 * b;

  const l3 = l * l * l;
  const m3 = m * m * m;
  const s3 = s * s * s;

  let r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
  let g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  let b2 = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.707614701 * s3;

  r = linearToSrgb(r);
  g = linearToSrgb(g);
  b2 = linearToSrgb(b2);

  return {
    r: clamp255(r * 255),
    g: clamp255(g * 255),
    b: clamp255(b2 * 255),
  };
}

function linearToSrgb(value: number): number {
  if (value <= 0.0031308) return 12.92 * value;
  return 1.055 * Math.pow(value, 1 / 2.4) - 0.055;
}

function parseRgbNumber(value: string): number | undefined {
  const trimmed = value.trim();
  if (trimmed.endsWith('%')) {
    const percent = parseFloat(trimmed);
    if (Number.isNaN(percent)) return;
    return clamp255((percent / 100) * 255);
  }

  const num = parseFloat(trimmed);
  if (Number.isNaN(num)) return;
  return clamp255(num);
}

function parseAlpha(value: string): number | undefined {
  const trimmed = value.trim();
  if (trimmed.endsWith('%')) {
    const percent = parseFloat(trimmed);
    if (Number.isNaN(percent)) return;
    return Math.min(Math.max(percent / 100, 0), 1);
  }

  const num = parseFloat(trimmed);
  if (Number.isNaN(num)) return;
  return Math.min(Math.max(num, 0), 1);
}

function clamp255(value: number): number {
  return Math.min(Math.max(Math.round(value), 0), 255);
}

function toHex(value: number): string {
  return value.toString(16).padStart(2, '0');
}

function expandShortHex(hex: string): string {
  return `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}`;
}

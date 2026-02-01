// Interaction handlers for click/touch/hover and drilldown URL building.
import type { ActiveElement, Chart, ChartEvent } from 'chart.js';
import { BarElement } from 'chart.js';

type TouchIndexState = {
  get: () => number | null;
  set: (value: number | null) => void;
};

// Wraps getter/setter into a touch index state helper.
export const createTouchIndexState = (
  getter: () => number | null,
  setter: (value: number | null) => void,
): TouchIndexState => ({
  get: getter,
  set: setter,
});

// Resets zoom on double click, if zoom plugin is present.
export const handleDoubleClickReset = (chart?: Chart): void => {
  chart?.resetZoom();
};

// Handles tap/click behavior with a two-tap confirm for touch devices.
export const handleTouchOrClick = (
  isTouchEnabled: () => boolean,
  state: TouchIndexState,
  dataIndex: number,
  action: () => void,
): void => {
  if (isTouchEnabled()) {
    if (state.get() === dataIndex) {
      action();
      state.set(null);
    } else {
      state.set(dataIndex);
    }
    return;
  }

  action();
};

// Resolves drilldown target from chart elements and triggers callbacks.
export const handleChartClick = (
  elements: ActiveElement[],
  chart: Chart,
  onDrilldownPath: (path: string) => void,
  onDrilldownTimestamp: (timestamp: number) => void,
): void => {
  if (elements.length === 0) return;

  const dataIndex = elements[0].index;
  const dataset = chart.data.datasets[elements[0].datasetIndex];

  const rawData = dataset.data?.[dataIndex] as
    | { drilldownPath?: string; timestamp?: number }
    | undefined;
  if (rawData?.drilldownPath) {
    onDrilldownPath(rawData.drilldownPath);
    return;
  }

  const barLabel = chart.data.labels?.[dataIndex];
  if (typeof barLabel !== 'number') return;

  onDrilldownTimestamp(barLabel);
};

// Sets pointer cursor when the hovered element is interactive.
export const handleHoverCursor = (
  event: ChartEvent,
  elements: ActiveElement[],
  chart: Chart,
): void => {
  if (!(event?.native?.target instanceof HTMLCanvasElement)) return;

  let showPointer = false;
  if (elements.length) {
    if (elements[0].element instanceof BarElement) {
      showPointer = true;
    }
    const dataset = chart.data.datasets[elements[0].datasetIndex];
    const rawData = dataset.data?.[elements[0].index] as
      | { drilldownPath?: string }
      | undefined;
    if (rawData?.drilldownPath) {
      showPointer = true;
    }
  }

  event.native.target.style.cursor = showPointer ? 'pointer' : 'default';
};

// Builds a drilldown URL by advancing the current aggregation level.
export const buildDrilldownUrl = (
  currentUrl: string,
  timestamp: number,
): string | null => {
  const date = new Date(timestamp);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');

  const drilldownLevels: Array<{ regex: RegExp; format: () => string }> = [
    { regex: /(\/all)$/, format: () => `${year}` },
    { regex: /(\/\d{4}|\/year)$/, format: () => `${year}-${month}` },
    {
      regex: /(\/\d{4}-\d{2}|\/month)$/,
      format: () => `${year}-${month}-${day}`,
    },
    {
      regex: /(\/\d{4}-W\d{2}|\/week)$/,
      format: () => `${year}-${month}-${day}`,
    },
    {
      regex: /(\/\d{4}-\d{2}-\d{2}\.\.\d{4}-\d{2}-\d{2})$/,
      format: () => `${year}-${month}-${day}`,
    },
    { regex: /(\/P\d{1,3}D)$/, format: () => `${year}-${month}-${day}` },
    { regex: /(\/P\d{1,2}M)$/, format: () => `${year}-${month}` },
    { regex: /(\/P\d{1,2}Y)$/, format: () => `${year}` },
  ];

  for (const { regex, format } of drilldownLevels) {
    const match = regex.exec(currentUrl);
    const value = match?.[1];
    if (!value) continue;

    const formattedDate = format();
    return currentUrl.replace(value, `/${formattedDate}`);
  }

  return null;
};

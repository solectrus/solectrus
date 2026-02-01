// Detects power-balance context and configures the external tooltip.
import type { ChartData, ChartOptions } from 'chart.js';

import type { TooltipContext } from './power_balance_tooltip';

import type { DatasetWithId } from './types';

export type PowerBalanceFlags = {
  isPowerBalance: boolean;
  sourceIds: Set<string>;
  usageIds: Set<string>;
  orderMap: Map<string, number>;
  isPowerSplitterStack: boolean;
  isInverterStack: boolean;
  isHeatingStack: boolean;
};

type TooltipLike = {
  destroy: () => void;
  render: (
    context: TooltipContext,
    sourceIds: Set<string>,
    usageIds: Set<string>,
    orderMap: Map<string, number>,
  ) => void;
};

// Computes flags and ID sets to detect power-balance charts.
export const getPowerBalanceFlags = (data: ChartData): PowerBalanceFlags => {
  const isPowerSplitterStack = data.datasets.some(
    (dataset) => dataset.stack == 'Power-Splitter',
  );
  const isInverterStack = data.datasets.some(
    (dataset) => dataset.stack == 'InverterPower',
  );
  const isHeatingStack = data.datasets.some(
    (dataset) => dataset.stack == 'HeatingPower',
  );

  const sourceIds = new Set([
    'inverter_power',
    'inverter_power_forecast',
    'battery_discharging_power',
    'grid_import_power',
  ]);

  const usageIds = new Set([
    'house_power',
    'heatpump_power',
    'wallbox_power',
    'battery_charging_power',
    'grid_export_power',
  ]);

  const stacks = new Set(['source', 'usage', 'combined']);
  const hasStack = data.datasets.some((dataset) =>
    stacks.has(dataset.stack ?? ''),
  );

  const hasSources = data.datasets.some((dataset) =>
    sourceIds.has((dataset as DatasetWithId).id ?? ''),
  );

  const hasUsage = data.datasets.some((dataset) =>
    usageIds.has((dataset as DatasetWithId).id ?? ''),
  );

  const orderMap = new Map(
    data.datasets.map((dataset, index) => [
      (dataset as DatasetWithId).id ?? '',
      index,
    ]),
  );

  return {
    sourceIds,
    usageIds,
    orderMap,
    isPowerBalance: hasStack && hasSources && hasUsage,
    isPowerSplitterStack,
    isInverterStack,
    isHeatingStack,
  };
};

// Enables/disables the external power-balance tooltip based on flags.
export const configurePowerBalanceTooltip = <T extends TooltipLike>(
  tooltip: NonNullable<NonNullable<ChartOptions['plugins']>['tooltip']>,
  flags: Pick<
    PowerBalanceFlags,
    'isPowerBalance' | 'sourceIds' | 'usageIds' | 'orderMap'
  >,
  context: {
    getTooltip: () => T | undefined;
    setTooltip: (tooltip: T | undefined) => void;
    buildTooltip: () => T;
  },
): void => {
  if (flags.isPowerBalance) {
    if (!context.getTooltip()) {
      context.setTooltip(context.buildTooltip());
    }

    tooltip.enabled = false;
    tooltip.external = (contextArg) =>
      context
        .getTooltip()
        ?.render(contextArg, flags.sourceIds, flags.usageIds, flags.orderMap);
    return;
  }

  const existing = context.getTooltip();
  if (existing) {
    existing.destroy();
    context.setTooltip(undefined);
  }
};

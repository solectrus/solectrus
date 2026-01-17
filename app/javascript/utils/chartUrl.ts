const NAMESPACED_CONTROLLERS = new Set(['house', 'inverter', 'heatpump']);

export const buildChartUrlFromHomeUrl = (homeUrl: string): string | null => {
  try {
    const url = new URL(homeUrl, globalThis.location.origin);
    const chartName = url.searchParams.get('chart_name');
    if (chartName) url.searchParams.delete('chart_name');

    const segments = url.pathname.split('/').filter(Boolean);
    if (segments.length === 0) return null;

    const namespace: string | null = NAMESPACED_CONTROLLERS.has(segments[0])
      ? (segments.shift() ?? null)
      : null;

    if (segments.length === 0) return null;

    const chartSegments = [];
    if (namespace) chartSegments.push(namespace);
    chartSegments.push('charts', ...segments);
    if (chartName) chartSegments.push(encodeURIComponent(chartName));

    url.pathname = `/${chartSegments.join('/')}`;

    return url.toString();
  } catch {
    return null;
  }
};

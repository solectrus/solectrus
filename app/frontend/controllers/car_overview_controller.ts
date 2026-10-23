import { Controller, type ActionEvent } from '@hotwired/stimulus';
import type StatsWithChartController from '../../components/stats_with_chart/component_controller';
import { isModifiedClick } from '@/utils/click';

// The overview of the car page: a column for the charging and one for the
// driving, each with its figures and its chart (see Car::Section). A figure
// loads its chart in its column. The menu of a chart picks here, and the
// pick loads in the column of its chart: on a phone, the menu of each chart
// offers the charts of both columns.
//
// A phone shows one chart below the figures of both columns, the one of the
// column of the last pick.
export default class extends Controller {
  static readonly targets = ['column'];
  static readonly outlets = ['stats-with-chart--component'];

  declare readonly columnTargets: HTMLElement[];
  declare readonly statsWithChartComponentOutlets: StatsWithChartController[];

  // An entry of the menu of a chart, which loads in the column of its chart
  loadChart(event: ActionEvent) {
    if (isModifiedClick(event)) return;

    const { sensorName, chartUrl } = event.params;
    const href = (event.currentTarget as HTMLElement).getAttribute('href');
    const column = this.columnFor(sensorName);
    const chart =
      column &&
      this.statsWithChartComponentOutlets.find((each) =>
        column.contains(each.element),
      );
    if (!href || !chart) return;

    event.preventDefault();
    chart.showChart(href, sensorName, chartUrl);
  }

  // A column shows the chart of a sensor (see
  // stats-with-chart--component#showChart), so a phone shows this column
  shown(event: Event) {
    const column = this.columnOf(event.target as Element);
    if (!column) return;

    this.columnTargets.forEach((each) => {
      each.dataset.active = String(each === column);
    });
  }

  // The column whose charts include the sensor (see Car::Section)
  private columnFor(sensor: string) {
    return this.columnTargets.find((column) =>
      column.dataset.carOverviewCharts?.split(' ').includes(sensor),
    );
  }

  private columnOf(element: Element) {
    return this.columnTargets.find((column) => column.contains(element));
  }
}

import { Controller } from '@hotwired/stimulus';
import { Chart } from 'chart.js';

export default class extends Controller {
  static targets = ['current'];

  static values = {
    src: String,
  };

  connect() {
    this.interval = setInterval(async () => {
      // Reload frame
      this.element.src = null;
      this.element.src = this.srcValue;
      await this.element.loaded;

      this.updateChart();
    }, 5000);
  }

  disconnect() {
    clearInterval(this.interval);
  }

  updateChart() {
    if (!this.hasCurrentTarget) {
      console.warn('RefreshController: Target "current" not found!');
      return;
    }

    let chart = this.chartNow;

    if (!chart) {
      console.warn('RefreshController: Chart not found!');
      return;
    }

    // Remove oldest point (label + value in all datasets)
    chart.data.labels.shift();
    chart.data.datasets.forEach((dataset) => {
      dataset.data.shift();
    });

    // Add new point (label + value)
    // Assume the value is from NOW, no need to get the real one
    chart.data.labels.push(new Date().toISOString());

    // There may be two datasets: One for positive, one for negative values.
    // Write currentValue to the appropriate dataset
    if (this.currentValue > 0) {
      this.positiveDataset(chart)?.data.push(this.currentValue);
      this.negativeDataset(chart)?.data.push(0);
    } else {
      this.negativeDataset(chart)?.data.push(this.currentValue);
      this.positiveDataset(chart)?.data.push(0);
    }

    chart.update();
  }

  get chartNow() {
    return Object.values(Chart.instances).find(
      (c) => c.canvas.id == 'chart-now',
    );
  }

  get currentValue() {
    return parseFloat(this.currentTarget.dataset.value);
  }

  // The positive dataset is where at least one positive value exist
  positiveDataset(chart) {
    return chart.data.datasets.find((dataset) =>
      dataset.data.some((v) => v > 0),
    );
  }

  // The negative dataset is where at least one negative value exist
  negativeDataset(chart) {
    return chart.data.datasets.find((dataset) =>
      dataset.data.some((v) => v < 0),
    );
  }
}

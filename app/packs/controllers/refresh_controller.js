import { Controller } from '@hotwired/stimulus';
import { Chart } from 'chart.js';

export default class extends Controller {
  static targets = ['current'];

  static values = {
    src: String,
  };

  connect() {
    this.interval = setInterval(() => {
      // Reload frame by using this hack: Remove "src" attribute and re-add it again
      this.element.removeAttribute('src');
      this.element.setAttribute('src', this.srcValue);

      // Wait until the frame is loaded before updating the chart
      // TODO: Is there a callback for doing this?
      setTimeout(() => {
        this.updateChart();
      }, 250);
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

    // Remove first point (label + value)
    chart.data.labels.shift();
    chart.data.datasets[0].data.shift();

    // Add new point (label + value)
    // Assume the value is from NOW, no need to get the real one
    chart.data.labels.push(new Date().toISOString());
    chart.data.datasets[0].data.push(this.currentValue);

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
}

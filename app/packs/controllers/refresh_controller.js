import { Controller } from "stimulus"
import Chart from "chart.js"

export default class extends Controller {
  static targets = ['current']

  static values = {
    src: String
  }

  connect() {
    this.timeout = setInterval(() => {
      this.element.setAttribute('src', this.srcValue)

      // Wait until the frame is loaded before updating the chart
      // TODO: Is there a callback for doing this?
      setTimeout(() => { this.updateChart() }, 250)
    }, 5000);
  }

  disconnect() {
    clearInterval(this.timeout)
  }

  updateChart() {
    if (!this.hasCurrentTarget) {
      console.warn('RefreshController: Target "current" not found!')
      return
    }

    if (!this.chart) {
      console.warn('RefreshController: Chart not found!')
      return
    }

    if (!this.chart.data) {
      console.warn('RefreshController: Chart data not found!')
      return
    }

    let data = this.chart.data

    // Remove first point
    data.labels.shift()
    data.datasets[0].data.shift()

    // Add new point
    // Assume the value is from NOW, no need to get the real one
    data.labels.push(new Date().toISOString())
    data.datasets[0].data.push(this.currentValue)

    this.chart.data = data
    this.chart.options.animation.duration = 0
    this.chart.update()
  }

  get chart() {
    return Object.values(Chart.instances).find((c) => c.canvas.id == 'chart-now')
  }

  get currentValue() {
    return parseFloat(this.currentTarget.dataset.value)
  }
}

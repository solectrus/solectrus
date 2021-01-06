import { Controller } from "stimulus"

export default class extends Controller {
  static targets = ['current']

  static values = {
    src: String
  }

  connect() {
    this.timeout = setTimeout(() => {
      this.element.setAttribute('src', this.srcValue)

      // Wait until the frame is loaded before updating the chart
      // TODO: Is there a callback for doing this?
      setTimeout(() => { this.updateChart() }, 2500)
    }, 5000);
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  updateChart() {
    const data = this.chart.data[0].data
    data.shift()
    data.push(
      // Assume the value is from NOW, no need to get the real one
      [new Date().toISOString(), this.latestValue]
    )

    var options = this.chart.options
    options.library.animation.duration = 0

    this.chart.updateData(data, options)
  }

  get chart() {
    return Chartkick.charts["chart-1"]
  }

  get latestValue() {
    return parseFloat(this.currentTarget.innerHTML.replace(',', '.'))
  }
}

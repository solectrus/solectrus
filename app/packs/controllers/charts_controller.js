import { Controller } from "stimulus"

import moment from "moment"
import "moment/locale/de"
import Chart from "chart.js"

export default class extends Controller {
  static values = {
    type: String,
    url: String,
    options: Object
  }

  connect() {
    moment.locale(window.navigator.userLanguage || window.navigator.language)

    var that = this
    fetch(this.urlValue)
      .then(response => response.json())
      .then(data => {
        var options = this.optionsValue

        // Format numbers on y-axis
        options.scales.yAxes[0].ticks.callback = function(value, index, values) {
          return that.formattedNumber(value)
        }

        // Format numbers in tooltips
        options.tooltips.callbacks.label = function (tooltipItem, data) {
          let label = data.datasets[tooltipItem.datasetIndex].label || ''
          if (label) {
            label += ': '
          }
          return label + that.formattedNumber(tooltipItem['yLabel'])
        }

        this.chart = new Chart(this.element, {
          type: this.typeValue,
          data: data,
          options: options
        })
      })
  }

  disconnect() {
    if (this.chart)
      this.chart.destroy()
  }

  formattedNumber(number) {
    return new Intl.NumberFormat().format(number)
  }
}

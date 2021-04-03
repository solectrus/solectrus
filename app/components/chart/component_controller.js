import { Controller } from "stimulus"

import {
  Chart,
  LineElement,
  BarElement,
  PointElement,
  BarController,
  LineController,
  LinearScale,
  TimeSeriesScale,
  Filler,
  Title,
  Tooltip
} from 'chart.js'

import 'chartjs-adapter-date-fns'
import { de } from 'date-fns/locale'

Chart.register(
  LineElement,
  BarElement,
  PointElement,
  BarController,
  LineController,
  LinearScale,
  TimeSeriesScale,
  Filler,
  Title,
  Tooltip
)

export default class extends Controller {
  static values = {
    type: String,
    url: String,
    options: Object
  }

  connect() {
    var that = this
    fetch(this.urlValue)
      .then(response => response.json())
      .then(data => {
        var options = this.optionsValue

        // I18n
        options.scales.x.adapters = {
          date: {
            locale: de
          }
        }

        // Format numbers on y-axis
        options.scales.y.ticks.callback = function(value, index, values) {
          return that.formattedNumber(value)
        }

        // Format numbers in tooltips
        options.plugins.tooltip.callbacks = {
          label: (context) => {
            return context.dataset.label + ': ' + that.formattedNumber(context.parsed.y)
          }
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

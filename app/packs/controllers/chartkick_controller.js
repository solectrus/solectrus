import { Controller } from "stimulus"
import moment from "moment"

import "chartkick"
import "chart.js"
import "moment/locale/de"

export default class extends Controller {
  static values = {
    type: String,
    url: String,
    options: Object
  }

  connect() {
    moment.locale(window.navigator.userLanguage || window.navigator.language)
    new Chartkick[this.typeValue](this.element.id, this.urlValue, this.optionsValue)
  }
}

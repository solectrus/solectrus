import { Controller } from "stimulus"

export default class extends Controller {
  static values = {
    type: String,
    url: String,
    options: Object
  }

  connect() {
    new Chartkick[this.typeValue](this.element.id, this.urlValue, this.optionsValue)
  }
}

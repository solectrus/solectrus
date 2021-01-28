import { Controller } from "stimulus"

export default class extends Controller {
  static targets = [ "element" ]

  toggle(event) {
    event.preventDefault()

    this.elementTargets.forEach((element) => {
      if (element.classList.contains("hidden")) {
        element.classList.remove("hidden")
        element.classList.add("block")
      } else {
        element.classList.add("hidden")
        element.classList.remove("block")
      }
    })
  }
}

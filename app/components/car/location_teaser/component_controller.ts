import { Controller } from '@hotwired/stimulus';

// The sample map of a visitor (see Car::LocationTeaser::Component). The live
// view refreshes by a morph, which would empty the map. The map never
// changes, so the morph leaves it as it is.

export default class extends Controller<HTMLElement> {
  keep(event: Event) {
    if (event.target === this.element) event.preventDefault();
  }
}

import { Controller } from '@hotwired/stimulus';
import Plausible from 'plausible-tracker';

export default class extends Controller {
  static values = {
    url: String,
    domain: String,
  };

  initialize() {
    if (this.hasUrlValue) {
      this.plausible = Plausible({
        domain: this.domainValue || window.location.host,
        apiHost: this.urlValue,
      });
    }
  }

  connect() {
    if (this.plausible) this.plausible.trackPageview();
  }
}

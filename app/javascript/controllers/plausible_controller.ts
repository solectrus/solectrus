import { Controller } from '@hotwired/stimulus';
import { init, track } from '@plausible-analytics/tracker';

export default class extends Controller {
  static readonly values = {
    url: String,
    domain: String,
  };

  declare urlValue: string;
  declare readonly hasUrlValue: boolean;

  declare domainValue: string;
  declare readonly hasDomainValue: boolean;

  private plausible: boolean = false;

  initialize() {
    if (this.hasUrlValue) {
      init({
        domain: this.domainValue || window.location.host,
        endpoint: `${this.urlValue}/api/event`,
        autoCapturePageviews: false,
      });
      this.plausible = true;
    }
  }

  connect() {
    if (this.plausible) track('pageview', {});
  }
}

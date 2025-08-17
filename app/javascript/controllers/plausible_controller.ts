import { Controller } from '@hotwired/stimulus';
import { init, track } from '@plausible-analytics/tracker';

declare global {
  interface Window {
    plausible?: unknown;
  }
}

export default class extends Controller {
  static readonly values = {
    url: String,
    domain: String,
  };

  declare urlValue: string;
  declare readonly hasUrlValue: boolean;

  declare domainValue: string;
  declare readonly hasDomainValue: boolean;

  initialize() {
    if (this.hasUrlValue && !window.plausible) {
      init({
        domain: this.domainValue || window.location.host,
        endpoint: `${this.urlValue}/api/event`,
        autoCapturePageviews: false,
      });
    }
  }

  connect() {
    if (window.plausible) track('pageview', {});
  }
}

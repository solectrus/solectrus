import { Controller } from '@hotwired/stimulus';
import { init, track } from '@plausible-analytics/tracker';

// Whether init() of the imported tracker module ran. window.plausible cannot
// answer that: the tracker only sets it at the end of init(), and anything
// else - a browser extension, a blocker stub - can define it too. Trusting it
// made connect() call track() on an uninitialized module, which throws
// "plausible.track() can only be called after plausible.init()".
let initialized = false;

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
    if (!this.hasUrlValue || initialized) return;

    init({
      domain: this.domainValue || window.location.host,
      endpoint: `${this.urlValue}/api/event`,
      autoCapturePageviews: false,
    });
    initialized = true;
  }

  connect() {
    if (initialized) track('pageview', {});
  }
}

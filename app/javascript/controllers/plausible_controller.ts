import { Controller } from '@hotwired/stimulus';
import Plausible from 'plausible-tracker';

export default class extends Controller {
  static readonly values = {
    url: String,
    domain: String,
  };

  declare urlValue: string;
  declare readonly hasUrlValue: boolean;

  declare domainValue: string;
  declare readonly hasDomainValue: boolean;

  private plausible: ReturnType<typeof Plausible> | undefined;

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

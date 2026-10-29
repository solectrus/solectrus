import { Controller } from '@hotwired/stimulus';
import type ConfirmDialogController from '../../components/ui/confirm_dialog/component_controller';

// HELIOS answers on a port of its own, which the browser cannot always reach,
// like from outside the home network behind a reverse proxy. So a click asks
// HELIOS first. Without an answer, the dialog lets the user open it anyway,
// because the browser can also block the request while the link works, like
// plain HTTP from a page over HTTPS.
//
// The request goes without CORS: its answer stays opaque, but it arrives only
// when HELIOS is reachable. Safari opens a tab only within a second of the
// click, so the request must not take longer.
const TIMEOUT = 1000;

export default class extends Controller<HTMLAnchorElement> {
  static readonly outlets = ['ui--confirm-dialog--component'];
  static readonly values = { message: String, openLabel: String };

  declare readonly uiConfirmDialogComponentOutlet: ConfirmDialogController;
  declare readonly messageValue: string;
  declare readonly openLabelValue: string;

  async open(event: Event) {
    event.preventDefault();
    const url = this.element.href;

    const reachable = await fetch(`${url}/up`, {
      mode: 'no-cors',
      cache: 'no-store',
      signal: AbortSignal.timeout(TIMEOUT),
    }).then(
      () => true,
      () => false,
    );

    if (
      reachable ||
      (await this.uiConfirmDialogComponentOutlet.confirm(this.messageValue, {
        confirmLabel: this.openLabelValue,
      }))
    )
      window.open(url, '_blank');
  }
}

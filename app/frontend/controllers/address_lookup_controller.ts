import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { metaContent } from '@/utils/metaContent';

// Checks the address of an offsite charging session after the user changed
// it. The server answers with streams: the address in its normal form with
// its position and its map, or with an error (see
// Cars::ChargingSessionAddressesController). The save checks the address
// again, so a failed request changes nothing.
//
// It asks once for each change, when the field loses the focus, and never
// while the user types: the usage policy of Nominatim forbids an
// autocomplete. A form that needs Nominatim when it opens asks once it is
// shown, so the page does not wait for Nominatim (see
// ChargingSession::AddressLookup#pending?).
export default class extends Controller<HTMLElement> {
  static readonly values = { url: String, pending: Boolean };
  // The fields are the address and the position that the form carries for
  // it (see the partial address). The map is where the user moves the point.
  static readonly targets = [
    'fields',
    'address',
    'latitude',
    'longitude',
    'spinner',
    'map',
  ];

  declare readonly urlValue: string;
  declare pendingValue: boolean;
  declare readonly fieldsTarget: HTMLElement;
  declare readonly addressTarget: HTMLInputElement;
  declare readonly latitudeTarget: HTMLInputElement;
  declare readonly longitudeTarget: HTMLInputElement;
  declare readonly spinnerTarget: HTMLElement;
  declare readonly hasMapTarget: boolean;
  declare readonly mapTarget: HTMLElement;

  private request?: AbortController;
  private form?: HTMLFormElement | null;
  // The fields and the map of the page, which the streams replace (see
  // handleReset)
  private originals: HTMLElement[] = [];

  connect() {
    this.originals = [this.fieldsTarget];
    if (this.hasMapTarget) this.originals.push(this.mapTarget);
    this.form = this.element.closest('form');
    this.form?.addEventListener('reset', this.handleReset);

    if (!this.pendingValue) return;

    this.pendingValue = false;
    void this.check(true);
  }

  disconnect() {
    this.form?.removeEventListener('reset', this.handleReset);
    this.request?.abort();
  }

  // The streams replace the fields without an event, so a change event tells
  // the form that they changed, and its save button follows (see the
  // form-dirty controller)
  fieldsTargetConnected(fields: HTMLElement) {
    fields.dispatchEvent(new Event('change', { bubbles: true }));
  }

  async lookUp() {
    await this.check();
  }

  // The point that the user moved on the map (see movable_point.ts). The
  // address stays, so the form still carries the position for it, and the
  // save keeps the new point. A change event tells the form that it changed.
  move(event: CustomEvent<{ latitude: number; longitude: number }>) {
    this.setPosition(this.latitudeTarget, event.detail.latitude);
    this.setPosition(this.longitudeTarget, event.detail.longitude);
    this.fieldsTarget.dispatchEvent(new Event('change', { bubbles: true }));
  }

  // A hidden field takes its value as its default, so a reset of the form,
  // like the discard button, cannot bring it back. The field keeps the value
  // of the page for it. The map puts its point back itself (see
  // movable_point.ts).
  private setPosition(field: HTMLInputElement, value: number) {
    field.dataset.original ??= field.value;
    field.value = String(value);
  }

  // A reset of the form, like the discard button, brings back the values of
  // the page. After a check of the address, the fields and the map of the
  // page come back in place of the ones of the streams. The event fires
  // before the reset of the fields, so the reset then takes the fields of
  // the page too. A check that still runs stops, so its answer does not
  // replace them again.
  private readonly handleReset = (): void => {
    this.request?.abort();
    for (const original of this.originals) {
      if (!original.isConnected)
        document.getElementById(original.id)?.replaceWith(original);
    }

    for (const field of [this.latitudeTarget, this.longitudeTarget]) {
      const { original } = field.dataset;
      if (original === undefined) continue;

      field.value = original;
      delete field.dataset.original;
    }
  };

  private async check(opened = false) {
    // The streams replace the field, so the checks below need the one that
    // asked
    const input = this.addressTarget;
    // The address goes in the body, so no access log shows it
    const body = new FormData();
    for (const field of this.fieldsTarget.querySelectorAll('input'))
      body.append(field.name, field.value);
    if (opened) body.append('opened', '1');
    const value = input.value;

    this.request?.abort();
    const request = (this.request = new AbortController());
    this.busy(input, true);

    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        body,
        headers: {
          Accept: 'text/vnd.turbo-stream.html',
          'X-CSRF-Token': metaContent('csrf-token') ?? '',
        },
        signal: request.signal,
      });
      // A user who changed the field, or types in it again, gets the answer
      // to the next change
      if (
        !response.ok ||
        input.value !== value ||
        document.activeElement === input
      )
        return;

      Turbo.renderStreamMessage(await response.text());
    } catch {
      // Aborted by the next change, or offline
    } finally {
      // The streams replace the field with one without the spinner, so only
      // a field that stays needs this
      if (this.request === request) this.busy(input, false);
    }
  }

  // The answer replaces the map, so the point does not move while the
  // form asks
  private busy(input: HTMLInputElement, busy: boolean) {
    input.toggleAttribute('aria-busy', busy);
    this.spinnerTarget.classList.toggle('hidden', !busy);
    if (!this.hasMapTarget) return;

    this.mapTarget.inert = busy;
    this.mapTarget.classList.toggle('opacity-60', busy);
  }
}

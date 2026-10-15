import { Controller } from '@hotwired/stimulus';
import { visit } from '@hotwired/turbo';
import type ConfirmDialogController from '../../components/ui/confirm_dialog/component_controller';

// Enables the save buttons of a form once a field changes. A button can stand
// outside the form and name it with its form attribute, like the save button
// of Ui::TitleBar::Component, so the controller finds the buttons among the
// elements of the form and not as targets.
//
// With Ui::ConfirmDialog::Component as its outlet, the controller asks on the
// desktop before a visit or a reload leaves the changes behind. A page form
// has the outlet, like the general settings (see
// FormPageHelper#page_form_data). A form in the modal does not. A phone does
// not ask, because the title bar starts its slide before the visit (see
// Ui::TitleBar::Component), and a canceled visit would stop the page halfway.
const DESKTOP_QUERY = '(min-width: 64rem)';

export default class extends Controller<HTMLFormElement> {
  static readonly outlets = ['ui--confirm-dialog--component'];

  declare readonly uiConfirmDialogComponentOutlet: ConfirmDialogController;

  private initialData = '';
  private lastCheckedData = '';
  private submitting = false;
  private leaving = false;

  connect() {
    this.initialData = this.formData();
    this.lastCheckedData = this.initialData;
    this.submitting = false;
    this.setDisabled(true);

    this.element.addEventListener('input', this.handleChange);
    this.element.addEventListener('change', this.handleChange);
    this.element.addEventListener('reset', this.handleReset);
    this.element.addEventListener('turbo:submit-start', this.handleSubmitStart);
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd);
    document.addEventListener('turbo:morph', this.handleMorph);
  }

  disconnect() {
    this.element.removeEventListener('input', this.handleChange);
    this.element.removeEventListener('change', this.handleChange);
    this.element.removeEventListener('reset', this.handleReset);
    this.element.removeEventListener(
      'turbo:submit-start',
      this.handleSubmitStart,
    );
    this.element.removeEventListener('turbo:submit-end', this.handleSubmitEnd);
    document.removeEventListener('turbo:morph', this.handleMorph);
  }

  uiConfirmDialogComponentOutletConnected(): void {
    document.addEventListener('turbo:before-visit', this.handleBeforeVisit);
    window.addEventListener('beforeunload', this.handleBeforeUnload);
  }

  uiConfirmDialogComponentOutletDisconnected(): void {
    document.removeEventListener('turbo:before-visit', this.handleBeforeVisit);
    window.removeEventListener('beforeunload', this.handleBeforeUnload);
  }

  private readonly handleChange = (): void => {
    if (this.submitting) return;

    // Skip if form data hasn't changed since last check,
    // avoids redundant work when both input and change fire
    const current = this.formData();
    if (current === this.lastCheckedData) return;

    this.lastCheckedData = current;
    this.setDisabled(current === this.initialData);
  };

  // A reset button, like the discard button of Ui::SaveBar::Component and
  // Ui::SubmitButton::Component, brings back the values of the page. The
  // event fires before the fields change, so the check waits for them.
  private readonly handleReset = (): void => {
    setTimeout(this.handleChange);
  };

  // A link inside the app, like the main navigation. The visit after a save
  // goes on, because the form is either still submitting or clean again.
  //
  // The dialog answers later, but the visit must stop now. So it stops each
  // time, and the controller visits the page itself once the user leaves.
  private readonly handleBeforeVisit = (event: Event): void => {
    if (this.leaving || !this.dirty()) return;

    event.preventDefault();
    const { url } = (event as CustomEvent<{ url: string }>).detail;
    void this.uiConfirmDialogComponentOutlet.confirmDiscard().then((leave) => {
      if (!leave) return;

      this.leaving = true;
      visit(url);
    });
  };

  // A reload or the closing of the tab. The browser shows its own text.
  private readonly handleBeforeUnload = (event: BeforeUnloadEvent): void => {
    if (this.dirty()) event.preventDefault();
  };

  private readonly handleSubmitStart = (): void => {
    this.submitting = true;
  };

  private readonly handleSubmitEnd = (event: Event): void => {
    const { success } = (event as CustomEvent).detail;
    if (success) this.resetState();
    this.submitting = false;
  };

  private readonly handleMorph = (): void => {
    this.resetState();
    this.submitting = false;
  };

  private dirty(): boolean {
    return (
      window.matchMedia(DESKTOP_QUERY).matches &&
      !this.submitting &&
      this.formData() !== this.initialData
    );
  }

  private resetState(): void {
    this.initialData = this.formData();
    this.lastCheckedData = this.initialData;
    this.setDisabled(true);
  }

  private setDisabled(disabled: boolean): void {
    for (const element of this.element.elements) {
      if (
        element instanceof HTMLButtonElement &&
        element.hasAttribute('data-form-dirty-submit')
      )
        element.disabled = disabled;
    }
  }

  private formData(): string {
    const data = new FormData(this.element);

    // Remove authenticity token from comparison
    data.delete('authenticity_token');

    return new URLSearchParams(
      data as unknown as Record<string, string>,
    ).toString();
  }
}

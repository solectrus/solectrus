import { Controller } from '@hotwired/stimulus';

// Enables the save buttons of a form once a field changes. A button can stand
// outside the form and name it with its form attribute, like the save button
// of Ui::TitleBar::Component, so the controller finds the buttons among the
// elements of the form and not as targets.
export default class extends Controller<HTMLFormElement> {
  private initialData = '';
  private lastCheckedData = '';
  private submitting = false;

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

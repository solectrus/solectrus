import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static readonly targets = ['submit'];

  declare readonly submitTarget: HTMLButtonElement;

  private initialData = '';
  private lastCheckedData = '';
  private submitting = false;

  connect() {
    this.initialData = this.formData();
    this.lastCheckedData = this.initialData;
    this.submitting = false;
    this.submitTarget.disabled = true;

    this.element.addEventListener('input', this.handleChange);
    this.element.addEventListener('change', this.handleChange);
    this.element.addEventListener('turbo:submit-start', this.handleSubmitStart);
    this.element.addEventListener('turbo:submit-end', this.handleSubmitEnd);
    document.addEventListener('turbo:morph', this.handleMorph);
  }

  disconnect() {
    this.element.removeEventListener('input', this.handleChange);
    this.element.removeEventListener('change', this.handleChange);
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
    this.submitTarget.disabled = current === this.initialData;
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
    this.submitTarget.disabled = true;
  }

  private formData(): string {
    const form = this.element as HTMLFormElement;
    const data = new FormData(form);

    // Remove authenticity token from comparison
    data.delete('authenticity_token');

    return new URLSearchParams(
      data as unknown as Record<string, string>,
    ).toString();
  }
}

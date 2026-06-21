import { Controller } from '@hotwired/stimulus';

// Handles the MCP settings UI:
//   - toggle: reveals/hides the access token when the checkbox changes (live,
//     without saving)
//   - copy: copies the token to the clipboard and briefly swaps the copy icon
//     for a checkmark as feedback
export default class extends Controller {
  static readonly values = { token: String };
  static readonly targets = ['token', 'copyIcon', 'doneIcon'];

  declare readonly tokenValue: string;
  declare readonly hasTokenTarget: boolean;
  declare readonly tokenTarget: HTMLElement;
  declare readonly hasCopyIconTarget: boolean;
  declare readonly copyIconTarget: HTMLElement;
  declare readonly hasDoneIconTarget: boolean;
  declare readonly doneIconTarget: HTMLElement;

  private resetTimeout?: number;

  toggle(event: Event): void {
    const enabled = (event.target as HTMLInputElement).checked;

    if (this.hasTokenTarget) {
      this.tokenTarget.classList.toggle('hidden', !enabled);
    }
  }

  async copy(event: Event): Promise<void> {
    event.preventDefault();

    try {
      await navigator.clipboard.writeText(this.tokenValue);
      this.showDone();
    } catch {
      // Clipboard API is unavailable (e.g. insecure context).
    }
  }

  disconnect(): void {
    window.clearTimeout(this.resetTimeout);
  }

  private showDone(): void {
    if (!this.hasCopyIconTarget || !this.hasDoneIconTarget) return;

    this.copyIconTarget.classList.add('hidden');
    this.doneIconTarget.classList.remove('hidden');

    window.clearTimeout(this.resetTimeout);
    this.resetTimeout = window.setTimeout(() => {
      this.copyIconTarget.classList.remove('hidden');
      this.doneIconTarget.classList.add('hidden');
      this.resetTimeout = undefined;
    }, 2000);
  }
}

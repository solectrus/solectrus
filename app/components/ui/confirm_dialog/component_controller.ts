import { Controller } from '@hotwired/stimulus';
import { config } from '@hotwired/turbo';

interface ConfirmOptions {
  confirmLabel?: string;
  destructive?: boolean;
}

// Asks before an action in the dialog of Ui::ConfirmDialog::Component, instead of
// the confirm of the browser. While the dialog is on the page, it answers
// every data-turbo-confirm. Another controller asks through an outlet, like
// form-dirty before unsaved changes are lost. The answer is true for the
// confirm button, and false for the cancel button, for Escape and for a
// click beside the panel.
export default class extends Controller<HTMLDialogElement> {
  static readonly targets = ['question', 'detail', 'accept'];
  static readonly values = {
    confirmLabel: String,
    discardQuestion: String,
    discardLabel: String,
  };

  declare readonly questionTarget: HTMLElement;
  declare readonly detailTarget: HTMLElement;
  declare readonly acceptTarget: HTMLButtonElement;
  declare readonly confirmLabelValue: string;
  declare readonly discardQuestionValue: string;
  declare readonly discardLabelValue: string;

  connect(): void {
    config.forms.confirm = this.confirmTurbo;
  }

  disconnect(): void {
    if (config.forms.confirm === this.confirmTurbo)
      config.forms.confirm = undefined;
  }

  confirm(message: string, options: ConfirmOptions = {}): Promise<boolean> {
    const dialog = this.element;

    // One question at a time. A second one while the first is open is no.
    if (dialog.open) return Promise.resolve(false);

    [this.questionTarget.textContent, this.detailTarget.textContent] =
      split(message);
    this.acceptTarget.textContent =
      options.confirmLabel ?? this.confirmLabelValue;
    dialog.toggleAttribute('data-destructive', options.destructive === true);
    dialog.returnValue = '';

    return new Promise((resolve) => {
      dialog.addEventListener(
        'close',
        () => {
          dialog.classList.remove('is-open');
          resolve(dialog.returnValue === 'confirm');
        },
        { once: true },
      );
      dialog.showModal();
      requestAnimationFrame(() => dialog.classList.add('is-open'));
    });
  }

  // The question before unsaved changes are lost
  confirmDiscard(): Promise<boolean> {
    return this.confirm(this.discardQuestionValue, {
      confirmLabel: this.discardLabelValue,
      destructive: true,
    });
  }

  // A click beside the panel lands on the dialog itself
  cancelBeside(event: MouseEvent): void {
    if (event.target === this.element) this.element.close('cancel');
  }

  // The element that carries data-turbo-confirm, the submit button or the
  // form, names the confirm button and marks an action that removes
  // something (see Ui::ConfirmDialog::Component.data)
  private readonly confirmTurbo = (
    message: string,
    form: HTMLFormElement,
    submitter?: HTMLElement | null,
  ): Promise<boolean> => {
    const source = [submitter, form].find((element) =>
      element?.hasAttribute('data-turbo-confirm'),
    );

    return this.confirm(message, {
      confirmLabel: source?.dataset.confirmButton,
      destructive: source?.hasAttribute('data-confirm-destructive'),
    });
  };
}

// A question can bring an explanation after it, like "Delete this entry?
// This cannot be undone." The text up to the first question mark is the
// question.
function split(message: string): [string, string] {
  const match = /^(.+?\?)\s+(.+)$/s.exec(message);
  return match ? [match[1], match[2]] : [message, ''];
}

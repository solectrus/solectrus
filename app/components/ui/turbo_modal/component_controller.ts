import { Controller } from '@hotwired/stimulus';
import { BottomSheet } from '@/utils/bottomSheet';
import { hideModalBackdrop, isModalBackdropPreloaded } from '@/utils/modal';
import type ConfirmDialogController from '../confirm_dialog/component_controller';

// Shows the page of a modal frame request in a BottomSheet, and removes it from
// the frame once it is closed. Before a form with unsaved changes closes, it
// asks in Ui::ConfirmDialog::Component, its outlet.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['dialog'];
  static readonly outlets = ['ui--confirm-dialog--component'];

  declare readonly dialogTarget: HTMLDialogElement;
  declare readonly hasUiConfirmDialogComponentOutlet: boolean;
  declare readonly uiConfirmDialogComponentOutlet: ConfirmDialogController;

  private sheet: BottomSheet | null = null;

  connect(): void {
    this.sheet = new BottomSheet(this.dialogTarget, {
      onClosed: () => this.element.remove(),
      // An open <details> inside takes Escape first
      canCancel: () => !this.dialogTarget.querySelector('details[open]'),
      confirmDiscard: () =>
        this.hasUiConfirmDialogComponentOutlet
          ? this.uiConfirmDialogComponentOutlet.confirmDiscard()
          : Promise.resolve(true),
    });

    // modal-launcher shows this backdrop at the click, while the frame loads.
    // The sheet dims the page itself. It takes over from the preloaded
    // backdrop without a fade, because both have the same color.
    this.sheet.open({ instant: isModalBackdropPreloaded() });
    hideModalBackdrop();
  }

  disconnect(): void {
    hideModalBackdrop();
    this.sheet?.destroy();
    this.sheet = null;
  }

  // Stimulus Action: Close with animation, for a button inside the content
  closeDialog(): void {
    this.sheet?.close();
  }

  // Stimulus Action: Close on successful form submission
  // Called via data-action="turbo:submit-end->ui--turbo-modal--component#submitEnd"
  submitEnd(event: CustomEvent): void {
    if (event.detail.success) this.closeDialog();
  }
}

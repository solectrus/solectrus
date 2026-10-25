import { Controller } from '@hotwired/stimulus';
import { preloadModalBackdrop } from '@/utils/modal';
import { MODAL_FRAME } from '../../components/ui/frames';
import type TooltipController from './tooltip_controller';

export default class extends Controller<HTMLElement> {
  connect(): void {
    // Register click handler in capture phase to ensure it runs before Turbo navigation
    this.element.addEventListener('click', this.handleClick, { capture: true });
  }

  disconnect(): void {
    // Clean up click handler
    this.element.removeEventListener('click', this.handleClick, {
      capture: true,
    });
  }

  // Handle click on the link - show backdrop immediately. Only while the link
  // loads into the modal. A click with a modifier opens a new tab or window,
  // and the modal of this page never loads.
  private readonly handleClick = (event: MouseEvent): void => {
    if (this.element.dataset.turboFrame !== MODAL_FRAME) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
      return;

    // Hide tooltip if present (tooltip controller is on the same element)
    this.hideTooltip();

    // Let Turbo handle the actual frame request normally
    // The modal controller will take over the backdrop
    preloadModalBackdrop();
  };

  private hideTooltip(): void {
    // Find the tooltip controller on the same element and hide it
    const tooltipController =
      this.application.getControllerForElementAndIdentifier(
        this.element,
        'tooltip',
      ) as TooltipController | null;

    tooltipController?.hide();
  }
}

import { Controller } from '@hotwired/stimulus';
import { enter } from 'el-transition';
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

  // Handle click on the link - show backdrop immediately
  private readonly handleClick = (): void => {
    // Hide tooltip if present (tooltip controller is on the same element)
    this.hideTooltip();

    const backdrop = document.getElementById('modal-backdrop');
    if (!backdrop) return;

    // Mark backdrop as preloaded so modal controller knows to skip animation
    backdrop.dataset.preloaded = 'true';

    // Enable pointer events and animate in the backdrop
    backdrop.classList.remove('pointer-events-none');
    enter(backdrop);

    // Let Turbo handle the actual frame request normally
    // The modal controller will take over the backdrop
  };

  private hideTooltip(): void {
    // Find the tooltip controller on the same element and hide it
    const tooltipController =
      this.application.getControllerForElementAndIdentifier(
        this.element,
        'tooltip',
      );

    if (tooltipController) {
      // Call the hide method (it's private but accessible at runtime)
      (tooltipController as TooltipController).hide();
    }
  }
}

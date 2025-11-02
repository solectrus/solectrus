import { Controller } from '@hotwired/stimulus';
import {
  computePosition,
  flip,
  shift,
  offset,
  arrow,
  autoUpdate,
} from '@floating-ui/dom';

/**
 * Tooltip controller for heatmap tile component
 * Shows tooltips for child elements with data-heatmap-tile--component-target='html'
 */
export default class extends Controller {
  static targets = ['html'];

  private tooltip: HTMLElement | null = null;
  private arrowElement: HTMLElement | null = null;
  private positionCleanup: (() => void) | null = null;

  connect() {
    this.createTooltip();
    this.element.addEventListener('mouseenter', this.handleEnter, true);
    this.element.addEventListener('mouseleave', this.handleLeave, true);
  }

  disconnect() {
    this.element.removeEventListener('mouseenter', this.handleEnter, true);
    this.element.removeEventListener('mouseleave', this.handleLeave, true);
    this.hideTooltip();
    this.tooltip?.remove();
  }

  private createTooltip(): void {
    this.tooltip = document.createElement('div');
    this.tooltip.className = 'floating-tooltip';
    this.tooltip.style.visibility = 'hidden';

    this.arrowElement = document.createElement('div');
    this.arrowElement.className = 'floating-tooltip-arrow';
    this.tooltip.appendChild(this.arrowElement);

    document.body.appendChild(this.tooltip);
  }

  private readonly handleEnter = (event: Event): void => {
    const target = event.target as HTMLElement;
    const htmlElement = target.querySelector(
      '[data-heatmap-tile--component-target="html"]',
    ) as HTMLElement | null;
    if (!htmlElement) return;

    this.showTooltip(target, htmlElement.innerHTML);
  };

  private readonly handleLeave = (event: Event): void => {
    const target = event.target as HTMLElement;
    const htmlElement = target.querySelector(
      '[data-heatmap-tile--component-target="html"]',
    ) as HTMLElement | null;

    if (htmlElement) {
      this.hideTooltip();
    }
  };

  private async showTooltip(
    target: HTMLElement,
    content: string,
  ): Promise<void> {
    if (!this.tooltip || !this.arrowElement) return;

    const arrowClone = this.arrowElement.cloneNode(true) as HTMLElement;
    this.tooltip.innerHTML = content;
    this.tooltip.appendChild(arrowClone);
    this.arrowElement = arrowClone;

    await this.updatePosition(target);

    this.tooltip.style.visibility = 'visible';
    this.tooltip.classList.add('show');

    this.positionCleanup = autoUpdate(target, this.tooltip, () =>
      this.updatePosition(target),
    );
  }

  private hideTooltip(): void {
    if (!this.tooltip) return;

    this.tooltip.style.visibility = 'hidden';
    this.tooltip.classList.remove('show');

    this.positionCleanup?.();
    this.positionCleanup = null;
  }

  private async updatePosition(target: HTMLElement): Promise<void> {
    if (!this.tooltip || !this.arrowElement) return;

    const { x, y, placement, middlewareData } = await computePosition(
      target,
      this.tooltip,
      {
        placement: 'bottom',
        middleware: [
          offset(10),
          flip(),
          shift({ padding: 5 }),
          arrow({ element: this.arrowElement }),
        ],
      },
    );

    Object.assign(this.tooltip.style, { left: `${x}px`, top: `${y}px` });

    if (middlewareData.arrow) {
      const { x: arrowX, y: arrowY } = middlewareData.arrow;
      const side = placement.split('-')[0];
      const staticSide = {
        top: 'bottom',
        right: 'left',
        bottom: 'top',
        left: 'right',
      }[side]!;

      Object.assign(this.arrowElement.style, {
        left: arrowX === null ? '' : `${arrowX}px`,
        top: arrowY === null ? '' : `${arrowY}px`,
        right: '',
        bottom: '',
        [staticSide]: '-6px',
      });
    }

    this.tooltip.dataset.placement = placement;
  }
}

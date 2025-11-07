import { Controller } from '@hotwired/stimulus';
import {
  computePosition,
  flip,
  shift,
  offset,
  arrow,
  autoUpdate,
  type Placement,
} from '@floating-ui/dom';
import { isTouchEnabled } from '@/utils/device';

const LONG_PRESS_DURATION = 500;

/**
 * Tooltip controller using Floating UI
 *
 * Displays tooltips with:
 * - Smart positioning that flips/shifts to stay in viewport
 * - Touch device support (tap or long-press)
 * - Bounce animation on show
 * - Arrow pointing to target element
 *
 * Operating modes:
 * 1. Standard mode (default):
 *    - One controller instance per tooltip element
 *    - Content from 'title' attribute or data-tooltip-target="html"
 *    - Works on the element itself (this.element)
 *    - Supports touch modes (tap, long-press) via data-tooltip-touch-value
 *
 * 2. Delegate mode (data-tooltip-delegate-value="true"):
 *    - One controller instance manages multiple child tooltips
 *    - Uses event delegation (mouseenter/mouseleave bubbling)
 *    - Efficient for grids/lists with many tooltip elements
 *    - Child elements need data-tooltip-target="html" with content
 *    - Works on touch devices via synthesized mouse events (tap shows tooltip)
 *    - Touch-specific modes (long-press, force-tap-to-close) not available
 */
export default class extends Controller {
  static readonly values = {
    // Where to place the tooltip relative to the target element
    placement: {
      type: String,
      default: 'bottom',
    },

    // How to handle tooltips on touch devices, can be "true", "false" or "long"
    touch: {
      type: String,
      default: 'false',
    },

    // Enable event delegation mode for handling multiple child tooltips efficiently
    delegate: {
      type: Boolean,
      default: false,
    },
  };

  static readonly targets = ['html'];

  declare placementValue: Placement;
  declare touchValue: 'true' | 'false' | 'long';
  declare delegateValue: boolean;
  declare readonly hasHtmlTarget: boolean;

  private tooltip: HTMLElement | null = null;
  private tooltipContent: HTMLElement | null = null;
  private arrowElement: HTMLElement | null = null;
  private positionCleanup: (() => void) | null = null;
  private overlay: HTMLElement | null = null;
  private titleObserver: MutationObserver | null = null;
  private contentObserver: MutationObserver | null = null;
  private touchTimer: ReturnType<typeof setTimeout> | null = null;
  private isVisible = false;

  connect() {
    if (this.delegateValue) {
      this.connectDelegated();
    } else {
      this.connectStandard();
    }
  }

  private connectStandard(): void {
    const title = this.element.getAttribute('title');
    if (title) {
      this.element.removeAttribute('title');
      this.watchTitle();

      // Set aria-label to keep a discernible text for accessibility
      (this.element as HTMLElement).ariaLabel = title;
    }

    const content = this.getContent();
    if (!content) return;

    this.createTooltip(content);
    this.setupEventListeners();
  }

  private connectDelegated(): void {
    this.createTooltip();
    this.element.addEventListener(
      'mouseenter',
      this.handleDelegatedEnter,
      true,
    );
    this.element.addEventListener(
      'mouseleave',
      this.handleDelegatedLeave,
      true,
    );
  }

  disconnect() {
    // Common cleanup
    if (this.isVisible) {
      this.removeOverlay();
      this.isVisible = false;
    }

    if (this.touchTimer) {
      clearTimeout(this.touchTimer);
      this.touchTimer = null;
    }

    this.titleObserver?.disconnect();
    this.titleObserver = null;

    this.contentObserver?.disconnect();
    this.contentObserver = null;

    // Mode-specific cleanup
    if (this.delegateValue) {
      this.element.removeEventListener(
        'mouseenter',
        this.handleDelegatedEnter,
        true,
      );
      this.element.removeEventListener(
        'mouseleave',
        this.handleDelegatedLeave,
        true,
      );
    } else {
      this.removeEventListeners();
    }

    this.hideTooltip();
    this.cleanupTooltip();
  }

  private watchTitle(): void {
    this.titleObserver = new MutationObserver(() =>
      this.element.removeAttribute('title'),
    );
    this.titleObserver.observe(this.element, {
      attributes: true,
      attributeFilter: ['title'],
    });
  }

  private getContent(): string {
    const htmlTarget = this.element.querySelector(
      '[data-tooltip-target="html"]',
    );
    return (
      htmlTarget?.innerHTML || (this.element as HTMLElement).ariaLabel || ''
    );
  }

  private setupEventListeners(): void {
    if (!isTouchEnabled()) {
      this.element.addEventListener('mouseenter', this.show);
      this.element.addEventListener('mouseleave', this.hide);
    } else if (this.touchValue === 'true') {
      this.element.addEventListener('click', this.handleClick);
    } else if (this.touchValue === 'long') {
      this.element.addEventListener('touchstart', this.handleTouchStart);
      this.element.addEventListener('touchend', this.cancelTouchTimer);
      this.element.addEventListener('touchcancel', this.cancelTouchTimer);
    }
  }

  private removeEventListeners(): void {
    this.element.removeEventListener('mouseenter', this.show);
    this.element.removeEventListener('mouseleave', this.hide);
    this.element.removeEventListener('click', this.handleClick);
    this.element.removeEventListener('touchstart', this.handleTouchStart);
    this.element.removeEventListener('touchend', this.cancelTouchTimer);
    this.element.removeEventListener('touchcancel', this.cancelTouchTimer);
  }

  private readonly handleClick = (event: Event): void => {
    // Don't prevent default for links - let them navigate
    if (this.element.tagName !== 'A') {
      event.preventDefault();
      event.stopPropagation();
    }

    if (this.isVisible) {
      this.hide();
    } else {
      this.show();
    }
  };

  private readonly handleTouchStart = (): void => {
    this.touchTimer = globalThis.setTimeout(() => {
      this.show();
      this.touchTimer = null;
    }, LONG_PRESS_DURATION);
  };

  private readonly cancelTouchTimer = (): void => {
    if (this.touchTimer) {
      clearTimeout(this.touchTimer);
      this.touchTimer = null;
    }
  };

  private readonly handleDelegatedEnter = (event: Event): void => {
    if (!(event.target instanceof HTMLElement)) return;

    const contentElement = event.target.querySelector(
      '[data-tooltip-target="html"]',
    );
    if (!(contentElement instanceof HTMLElement)) return;

    this.showTooltip(event.target, contentElement.innerHTML, contentElement);
  };

  private readonly handleDelegatedLeave = (event: Event): void => {
    if (!(event.target instanceof HTMLElement)) return;
    if (!event.target.querySelector('[data-tooltip-target="html"]')) return;

    this.hide();
  };

  private readonly handleOverlayClick = (): void => {
    this.hide();
  };

  private readonly show = async (): Promise<void> => {
    if (!this.tooltip || this.isVisible) return;

    const content = this.getContent();
    if (!content) return;

    const contentElement = this.hasHtmlTarget
      ? this.element.querySelector('[data-tooltip-target="html"]')
      : null;

    this.showTooltip(
      this.element as HTMLElement,
      content,
      contentElement instanceof HTMLElement ? contentElement : undefined,
    );
  };

  private async showTooltip(
    target: HTMLElement,
    content: string,
    observeElement?: HTMLElement,
  ): Promise<void> {
    this.updateTooltipContent(content);
    this.isVisible = true;

    await this.showTooltipAt(target, this.placementValue);

    // Check if controller was disconnected during async operation
    if (!this.tooltip || !this.isVisible) return;

    if (observeElement) {
      this.observeContentChanges(observeElement);
    }

    this.createOverlay();
  }

  readonly hide = (): void => {
    if (!this.isVisible || !this.tooltip) return;

    this.isVisible = false;

    this.hideTooltip();

    this.contentObserver?.disconnect();
    this.contentObserver = null;

    this.removeOverlay();
  };

  private observeContentChanges(target: Element): void {
    // Clean up existing observer first
    this.contentObserver?.disconnect();

    this.contentObserver = new MutationObserver(() => {
      const content = target.innerHTML;
      if (content) {
        this.updateTooltipContent(content);
      }
    });
    this.contentObserver.observe(target, {
      childList: true,
      subtree: true,
      characterData: true,
    });
  }

  private createOverlay(): void {
    if (!isTouchEnabled()) return;
    if (this.overlay) return; // Already exists

    this.overlay = document.createElement('div');
    this.overlay.className = 'tooltip-overlay';
    this.overlay.addEventListener('click', this.handleOverlayClick);
    document.body.appendChild(this.overlay);
  }

  private removeOverlay(): void {
    if (this.overlay) {
      this.overlay.removeEventListener('click', this.handleOverlayClick);
      this.overlay.remove();
      this.overlay = null;
    }
  }

  /**
   * Creates the tooltip element with arrow and adds it to the document body
   * or to an open dialog element (to appear in the top layer)
   */
  private createTooltip(initialContent = ''): void {
    this.tooltip = document.createElement('div');
    this.tooltip.className = 'floating-tooltip';
    this.tooltip.style.visibility = 'hidden';

    this.tooltipContent = document.createElement('div');
    this.tooltipContent.className = 'floating-tooltip-content';
    if (initialContent) {
      this.tooltipContent.innerHTML = initialContent;
    }
    this.tooltip.appendChild(this.tooltipContent);

    this.arrowElement = document.createElement('div');
    this.arrowElement.className = 'floating-tooltip-arrow';
    this.tooltip.appendChild(this.arrowElement);

    // Append to open dialog if exists (to appear in top layer), otherwise to body
    const openDialog = document.querySelector('dialog[open]');
    if (openDialog) {
      openDialog.appendChild(this.tooltip);
    } else {
      document.body.appendChild(this.tooltip);
    }
  }

  /**
   * Updates the tooltip content, preserving the arrow element
   */
  private updateTooltipContent(content: string): void {
    if (!this.tooltipContent) return;

    this.tooltipContent.innerHTML = content;
  }

  /**
   * Shows the tooltip at the specified target element
   */
  private async showTooltipAt(
    target: HTMLElement,
    placement: Placement = 'bottom',
  ): Promise<void> {
    if (!this.tooltip) return;

    // Cleanup existing position watcher before creating a new one
    this.positionCleanup?.();
    this.positionCleanup = null;

    await this.updateTooltipPosition(target, placement);

    this.tooltip.style.visibility = 'visible';
    this.tooltip.classList.add('show');

    this.positionCleanup = autoUpdate(target, this.tooltip, () =>
      this.updateTooltipPosition(target, placement),
    );
  }

  /**
   * Hides the tooltip and stops position updates
   */
  private hideTooltip(): void {
    if (!this.tooltip) return;

    this.tooltip.style.visibility = 'hidden';
    this.tooltip.classList.remove('show');

    this.positionCleanup?.();
    this.positionCleanup = null;
  }

  /**
   * Computes and applies the tooltip position using Floating UI
   */
  private async updateTooltipPosition(
    target: HTMLElement,
    placement: Placement = 'bottom',
  ): Promise<void> {
    if (!this.tooltip || !this.arrowElement) return;

    const {
      x,
      y,
      placement: actualPlacement,
      middlewareData,
    } = await computePosition(target, this.tooltip, {
      placement,
      middleware: [
        offset(10),
        flip(),
        shift({ padding: 5 }),
        arrow({ element: this.arrowElement }),
      ],
    });

    Object.assign(this.tooltip.style, { left: `${x}px`, top: `${y}px` });

    if (middlewareData.arrow) {
      const { x: arrowX, y: arrowY } = middlewareData.arrow;
      const side = actualPlacement.split('-')[0] as
        | 'top'
        | 'right'
        | 'bottom'
        | 'left';
      const staticSide: Record<typeof side, string> = {
        top: 'bottom',
        right: 'left',
        bottom: 'top',
        left: 'right',
      };

      Object.assign(this.arrowElement.style, {
        left: arrowX === null ? '' : `${arrowX}px`,
        top: arrowY === null ? '' : `${arrowY}px`,
        right: '',
        bottom: '',
        [staticSide[side]]: '-6px',
      });
    }

    this.tooltip.dataset.placement = actualPlacement;
  }

  /**
   * Cleans up the tooltip when the controller disconnects
   */
  private cleanupTooltip(): void {
    this.positionCleanup?.();
    this.positionCleanup = null;

    this.tooltip?.remove();
    this.tooltip = null;
    this.tooltipContent = null;
    this.arrowElement = null;
  }
}

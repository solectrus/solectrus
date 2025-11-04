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

/**
 * Tooltip controller using Floating UI
 *
 * Displays tooltips with:
 * - Smart positioning that flips/shifts to stay in viewport
 * - Touch device support (tap or long-press)
 * - Bounce animation on show
 * - Arrow pointing to target element
 */
export default class extends Controller {
  // Track all active tooltip instances to ensure only one is visible at a time
  private static readonly activeInstances = new Set<Controller>();
  private static documentClickListenerRegistered = false;

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

    // Force second tap (on touch device) to close tooltip
    forceTapToClose: {
      type: Boolean,
      default: true,
    },
  };

  static readonly targets = ['html'];

  declare placementValue: Placement;
  declare touchValue: 'true' | 'false' | 'long';
  declare forceTapToCloseValue: boolean;
  declare readonly hasHtmlTarget: boolean;

  private tooltip: HTMLElement | null = null;
  private arrowElement: HTMLElement | null = null;
  private positionCleanup: (() => void) | null = null;
  private titleObserver: MutationObserver | null = null;
  private contentObserver: MutationObserver | null = null;
  private touchTimer: ReturnType<typeof setTimeout> | null = null;
  private isVisible = false;
  private titleCache = '';
  private justShown = false;
  private blockNextClick = false;

  connect() {
    // Register this instance
    const constructor = this.constructor as typeof Controller & {
      activeInstances: Set<Controller>;
      documentClickListenerRegistered: boolean;
      handleGlobalDocumentClick: (event: Event) => void;
    };
    constructor.activeInstances.add(this);

    // Register global document click listener only once
    if (!constructor.documentClickListenerRegistered && this.isTouchDevice) {
      constructor.documentClickListenerRegistered = true;
      document.addEventListener('click', this.handleGlobalDocumentClick);
    }

    this.titleCache = this.element.getAttribute('title') || '';
    if (this.titleCache) {
      this.element.removeAttribute('title');
      this.watchTitle();

      // Set aria-label to keep a discernible text for accessibility
      (this.element as HTMLElement).ariaLabel = this.titleCache;
    }

    const content = this.getContent();
    if (!content) return;

    this.createTooltip(content);
    this.setupEventListeners();
  }

  disconnect() {
    // Unregister this instance
    const constructor = this.constructor as typeof Controller & {
      activeInstances: Set<Controller>;
      documentClickListenerRegistered: boolean;
      handleGlobalDocumentClick: (event: Event) => void;
    };
    constructor.activeInstances.delete(this);

    // Remove global listener if no instances left
    if (
      constructor.activeInstances.size === 0 &&
      constructor.documentClickListenerRegistered
    ) {
      constructor.documentClickListenerRegistered = false;
      document.removeEventListener('click', this.handleGlobalDocumentClick);
    }

    this.positionCleanup?.();
    this.titleObserver?.disconnect();
    this.contentObserver?.disconnect();
    this.tooltip?.remove();
    if (this.touchTimer) clearTimeout(this.touchTimer);
    this.removeEventListeners();
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
    if (this.hasHtmlTarget) {
      const target = this.element.querySelector('[data-tooltip-target="html"]');
      return target?.innerHTML || '';
    }
    return this.titleCache;
  }

  private createTooltip(content: string): void {
    this.tooltip = document.createElement('div');
    this.tooltip.className = 'floating-tooltip';
    this.tooltip.innerHTML = content;
    this.tooltip.style.visibility = 'hidden';

    this.arrowElement = document.createElement('div');
    this.arrowElement.className = 'floating-tooltip-arrow';
    this.tooltip.appendChild(this.arrowElement);

    document.body.appendChild(this.tooltip);
  }

  private updateContent(): void {
    if (!this.tooltip || !this.arrowElement) return;

    const content = this.getContent();
    if (!content) return;

    const arrowClone = this.arrowElement.cloneNode(true) as HTMLElement;
    this.tooltip.innerHTML = content;
    this.tooltip.appendChild(arrowClone);
    this.arrowElement = arrowClone;
  }

  private setupEventListeners(): void {
    const el = this.element;
    if (this.isTouchDevice) {
      if (this.isTapMode) {
        el.addEventListener('click', this.handleClick);
      } else if (this.isLongPressMode) {
        el.addEventListener('touchstart', this.handleTouchStart);
        el.addEventListener('touchend', this.handleTouchEnd);
        el.addEventListener('touchcancel', this.handleTouchCancel);
        el.addEventListener('click', this.preventClick, true);
      }
    } else {
      el.addEventListener('mouseenter', this.show);
      el.addEventListener('mouseleave', this.hide);
    }
  }

  private removeEventListeners(): void {
    const el = this.element;
    if (this.isTouchDevice) {
      if (this.isTapMode) {
        el.removeEventListener('click', this.handleClick);
      } else if (this.isLongPressMode) {
        el.removeEventListener('touchstart', this.handleTouchStart);
        el.removeEventListener('touchend', this.handleTouchEnd);
        el.removeEventListener('touchcancel', this.handleTouchCancel);
        el.removeEventListener('click', this.preventClick, true);
      }
    } else {
      el.removeEventListener('mouseenter', this.show);
      el.removeEventListener('mouseleave', this.hide);
    }
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
    }, this.longPressDuration);
  };

  private readonly handleTouchEnd = (): void => {
    const hadTimer = !!this.touchTimer;

    if (this.touchTimer) {
      clearTimeout(this.touchTimer);
      this.touchTimer = null;
    }

    // If tooltip is visible, distinguish between short tap and long-press end
    if (this.isVisible) {
      if (hadTimer) {
        this.blockNextClick = true;
        this.hide();
      } else {
        // Long-press just finished -> prevent immediate closing from click event
        this.justShown = true;
        globalThis.setTimeout(() => {
          this.justShown = false;
        }, this.clickProtectionDuration);
      }
    }
  };

  private readonly handleTouchCancel = (): void => {
    if (this.touchTimer) {
      clearTimeout(this.touchTimer);
      this.touchTimer = null;
    }
  };

  private readonly preventClick = (event: Event): void => {
    // Check if this specific tooltip wants to block the click
    if (this.blockNextClick) {
      this.blockNextClick = false;
      event.preventDefault();
      event.stopImmediatePropagation();
      return;
    }

    // Check if ANY tooltip is visible
    const constructor = this.constructor as typeof Controller & {
      activeInstances: Set<Controller>;
    };

    for (const instance of constructor.activeInstances) {
      const tooltipInstance = instance as typeof this;
      if (tooltipInstance.isVisible) {
        if (!tooltipInstance.justShown) {
          // Close tooltip if not just shown
          tooltipInstance.hide();
        }
        event.preventDefault();
        event.stopImmediatePropagation();
        return;
      }
    }
  };

  private readonly handleGlobalDocumentClick = (event: Event): void => {
    const constructor = this.constructor as typeof Controller & {
      activeInstances: Set<Controller>;
    };
    const target = event.target as Node;

    // Check all active tooltip instances
    for (const instance of constructor.activeInstances) {
      const tooltipInstance = instance as typeof this;

      // Skip if not visible or just shown
      if (!tooltipInstance.isVisible || tooltipInstance.justShown) continue;

      // Hide tooltip when clicking outside the target element
      // Note: tooltip has pointer-events: none, so clicks pass through
      if (!tooltipInstance.element.contains(target)) {
        tooltipInstance.hide();
        break; // Only hide one tooltip per click
      }
    }
  };

  private readonly show = async (): Promise<void> => {
    if (!this.tooltip || this.isVisible) return;

    // Hide all other tooltips first (only one tooltip should be visible at a time)
    const instances = (
      this.constructor as typeof Controller & {
        activeInstances: Set<Controller>;
      }
    ).activeInstances;
    for (const instance of instances) {
      if (instance !== this && (instance as typeof this).isVisible) {
        (instance as typeof this).hide();
      }
    }

    this.updateContent();
    this.isVisible = true;
    await this.updatePosition();

    this.tooltip.style.visibility = 'visible';
    this.tooltip.classList.add('show');

    this.positionCleanup = autoUpdate(
      this.element as HTMLElement,
      this.tooltip,
      () => this.updatePosition(),
    );

    if (this.hasHtmlTarget) {
      this.observeContent();
    }

    this.togglePointerEvents(true);
  };

  private readonly hide = (): void => {
    if (!this.isVisible || !this.tooltip) return;

    this.isVisible = false;
    this.tooltip.style.visibility = 'hidden';
    this.tooltip.classList.remove('show');

    this.positionCleanup?.();
    this.positionCleanup = null;

    this.contentObserver?.disconnect();
    this.contentObserver = null;

    this.togglePointerEvents(false);
  };

  private async updatePosition(): Promise<void> {
    if (!this.tooltip || !this.arrowElement) return;

    const { x, y, placement, middlewareData } = await computePosition(
      this.element as HTMLElement,
      this.tooltip,
      {
        placement: this.placementValue,
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

  private observeContent(): void {
    const target = this.element.querySelector('[data-tooltip-target="html"]');
    if (!target) return;

    this.contentObserver = new MutationObserver(() => this.updateContent());
    this.contentObserver.observe(target, {
      childList: true,
      subtree: true,
      characterData: true,
    });
  }

  private togglePointerEvents(active: boolean): void {
    if (this.isTouchDevice) {
      document.body.classList.toggle('active-tooltip', active);
    }
  }

  get isTouchDevice(): boolean {
    return 'ontouchstart' in globalThis;
  }

  get isLongPressMode(): boolean {
    return this.touchValue === 'long';
  }

  get isTapMode(): boolean {
    return this.touchValue === 'true';
  }

  get longPressDuration(): number {
    return 500;
  }

  get clickProtectionDuration(): number {
    // Duration to prevent immediate closing after showing tooltip
    // Needs to be long enough to catch the click event that follows touchend
    return 300;
  }
}

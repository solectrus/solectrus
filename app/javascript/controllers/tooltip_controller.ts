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
  private longPressTriggered = false;
  private titleCache = '';

  connect() {
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
      if (this.touch === true) {
        el.addEventListener('click', this.handleClick);
      } else if (Array.isArray(this.touch)) {
        el.addEventListener('touchstart', this.handleTouchStart);
        el.addEventListener('touchend', this.handleTouchEnd);
        el.addEventListener('touchcancel', this.handleTouchEnd);
        el.addEventListener('click', this.preventClickAfterLongPress);
      }
      document.addEventListener('click', this.handleDocumentClick);
    } else {
      el.addEventListener('mouseenter', this.show);
      el.addEventListener('mouseleave', this.hide);
    }
  }

  private removeEventListeners(): void {
    const el = this.element;
    if (this.isTouchDevice) {
      if (this.touch === true) {
        el.removeEventListener('click', this.handleClick);
      } else if (Array.isArray(this.touch)) {
        el.removeEventListener('touchstart', this.handleTouchStart);
        el.removeEventListener('touchend', this.handleTouchEnd);
        el.removeEventListener('touchcancel', this.handleTouchEnd);
        el.removeEventListener('click', this.preventClickAfterLongPress);
      }
      document.removeEventListener('click', this.handleDocumentClick);
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
    this.longPressTriggered = false;
    const [, duration] = this.touch as ['hold', number];

    this.touchTimer = globalThis.setTimeout(() => {
      this.longPressTriggered = true;
      this.show();
      this.touchTimer = null;
    }, duration);
  };

  private readonly handleTouchEnd = (): void => {
    if (this.touchTimer) {
      clearTimeout(this.touchTimer);
      this.touchTimer = null;
      this.longPressTriggered = false;
    } else if (this.isVisible) {
      this.hide();
    }
  };

  private readonly preventClickAfterLongPress = (event: Event): void => {
    if (!this.longPressTriggered) return;
    event.preventDefault();
    event.stopPropagation();
    this.longPressTriggered = false;
  };

  private readonly handleDocumentClick = (event: Event): void => {
    if (!this.isVisible) return;

    const target = event.target as Node;
    // Hide tooltip when clicking outside the target element
    // Note: tooltip has pointer-events: none, so clicks pass through
    if (!this.element.contains(target)) {
      this.hide();
    }
  };

  private readonly show = async (): Promise<void> => {
    if (!this.tooltip || this.isVisible) return;

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
    if (this.isTouchDevice && this.forceTapToCloseValue) {
      document.body.classList.toggle('active-tooltip', active);
    }
  }

  get isTouchDevice(): boolean {
    return 'ontouchstart' in globalThis;
  }

  get touch(): boolean | ['hold', number] {
    switch (this.touchValue) {
      case 'true':
        return true;
      case 'long':
        return ['hold', 500];
      default:
        return false;
    }
  }
}

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
// A long-press is canceled if the finger moves further than this (px) while
// waiting — prevents the tooltip from firing mid-swipe or mid-scroll
const LONG_PRESS_MOVE_TOLERANCE = 10;

// The one tooltip element of the document and the two nodes inside it that a
// controller writes to
interface SharedTooltip {
  tooltip: HTMLElement;
  content: HTMLElement;
  arrow: HTMLElement;
}

/**
 * Tooltip controller using Floating UI
 *
 * Displays tooltips with:
 * - Smart positioning that flips/shifts to stay in viewport
 * - Hybrid device support (mouse hover + optional touch modes)
 * - Bounce animation on show
 * - Arrow pointing to target element
 *
 * Operating modes:
 * 1. Standard mode (default):
 *    - One controller instance per tooltip element
 *    - Content from 'title' attribute or data-tooltip-target="html"
 *    - Works on the element itself (this.element)
 *    - Mouse hover always supported (pointerenter/pointerleave with pointerType check)
 *    - Optional touch modes (tap, long-press) via data-tooltip-touch-value
 *
 * 2. Delegate mode (data-tooltip-delegate-value="true"):
 *    - One controller instance manages multiple child tooltips
 *    - Uses event delegation (pointerenter/pointerleave bubbling)
 *    - Efficient for grids/lists with many tooltip elements
 *    - Child elements need data-tooltip-target="html" with content
 *    - Mouse hover supported via pointer events (only shows for pointerType === 'mouse')
 *    - Touch-specific modes (long-press, force-tap-to-close) not available
 */
export default class TooltipController extends Controller {
  private static activeTooltip: TooltipController | null = null;

  // One tooltip element for the whole document, built on first use. At most
  // one tooltip stands on the screen anyway, because `setActiveTooltip` hides
  // the one before it, so a single element does what one element per
  // controller did.
  //
  // It is also what keeps the box still on a Turbo render. Such a render
  // replaces the element a tooltip hangs on, so its controller disconnects
  // and the one on the new element takes over. Both drive the same box, and
  // that box keeps the opacity and the scale it has: `disconnect` drops the
  // `show` class, the stylesheet fades the box out over 200ms, and the
  // controller that takes over puts the class back and turns the fade around.
  // Nothing here measures time - the transition is the window.
  //
  // A tooltip of its own per controller had to be built and to grow from
  // nothing every time, although the pointer never moved - a blink.
  private static sharedTooltip: SharedTooltip | null = null;

  static readonly values = {
    // Where to place the tooltip relative to the target element
    placement: {
      type: String,
      default: 'bottom',
    },

    // Alternative placement on small screens (empty = use placement)
    mobilePlacement: {
      type: String,
      default: '',
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
  declare mobilePlacementValue: string;
  declare touchValue: 'true' | 'false' | 'long';
  declare delegateValue: boolean;
  declare readonly hasHtmlTarget: boolean;

  private positionCleanup: (() => void) | null = null;
  private overlay: HTMLElement | null = null;
  private titleObserver: MutationObserver | null = null;
  private contentObserver: MutationObserver | null = null;
  private touchTimer: ReturnType<typeof setTimeout> | null = null;
  private longPressStartX = 0;
  private longPressStartY = 0;
  private isVisible = false;
  private openedByTouch = false;

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

    this.setupEventListeners();
  }

  private connectDelegated(): void {
    if (!this.supportsHover()) return;

    this.element.addEventListener(
      'pointerenter',
      this.handleDelegatedPointerEnter,
      { capture: true, passive: true },
    );
    this.element.addEventListener(
      'pointerleave',
      this.handleDelegatedPointerLeave,
      { capture: true, passive: true },
    );
  }

  disconnect() {
    // The tooltip element outlives every controller, so only the controller
    // that put it on the screen may take it down. For every other one this
    // does nothing, which is what leaves the box alone when a Turbo render
    // replaces an unrelated element.
    this.hide();
    TooltipController.releaseActiveTooltip(this);

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
        'pointerenter',
        this.handleDelegatedPointerEnter,
        true,
      );
      this.element.removeEventListener(
        'pointerleave',
        this.handleDelegatedPointerLeave,
        true,
      );
    } else {
      this.removeEventListeners();
    }
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
    const hoverCapable = this.supportsHover();

    // Use pointer events for hover - only on devices that actually support hover
    if (hoverCapable) {
      this.element.addEventListener('pointerenter', this.showOnPointer, {
        passive: true,
      });
      this.element.addEventListener('pointerleave', this.hideOnPointer, {
        passive: true,
      });
    }

    // Add touch-specific events if configured and device supports touch
    if (isTouchEnabled()) {
      if (this.touchValue === 'true') {
        this.element.addEventListener('click', this.handleClick);
      } else if (this.touchValue === 'long') {
        this.element.addEventListener('touchstart', this.handleTouchStart, {
          passive: true,
        });
        this.element.addEventListener('touchmove', this.handleTouchMove, {
          passive: true,
        });
        this.element.addEventListener('touchend', this.cancelTouchTimer, {
          passive: true,
        });
        this.element.addEventListener('touchcancel', this.cancelTouchTimer, {
          passive: true,
        });
      }
    }
  }

  private removeEventListeners(): void {
    this.element.removeEventListener('pointerenter', this.showOnPointer);
    this.element.removeEventListener('pointerleave', this.hideOnPointer);
    this.element.removeEventListener('click', this.handleClick);
    this.element.removeEventListener('touchstart', this.handleTouchStart);
    this.element.removeEventListener('touchmove', this.handleTouchMove);
    this.element.removeEventListener('touchend', this.cancelTouchTimer);
    this.element.removeEventListener('touchcancel', this.cancelTouchTimer);
  }

  private readonly showOnPointer = (event: Event): void => {
    // Only show tooltip on actual mouse hover, not touch
    if (event instanceof PointerEvent && event.pointerType === 'mouse') {
      this.openedByTouch = false;
      this.show();
    }
  };

  private readonly hideOnPointer = (event: Event): void => {
    // Only hide on mouse leave, not on touch end (touch uses overlay click)
    if (event instanceof PointerEvent && event.pointerType === 'mouse') {
      this.hide();
    }
  };

  private readonly handleClick = (event: Event): void => {
    // Don't prevent default for links - let them navigate
    if (this.element.tagName !== 'A') {
      event.preventDefault();
      event.stopPropagation();
    }

    if (this.isVisible) {
      this.hide();
    } else {
      this.openedByTouch = true;
      this.show();
    }
  };

  private readonly handleTouchStart = (event: Event): void => {
    if (!(event instanceof TouchEvent)) return;
    const touch = event.changedTouches[0];
    this.longPressStartX = touch.screenX;
    this.longPressStartY = touch.screenY;
    this.touchTimer = globalThis.setTimeout(() => {
      this.openedByTouch = true;
      this.show();
      this.touchTimer = null;
    }, LONG_PRESS_DURATION);
  };

  private readonly handleTouchMove = (event: Event): void => {
    if (!this.touchTimer) return;
    if (!(event instanceof TouchEvent)) return;
    const touch = event.changedTouches[0];
    const dx = touch.screenX - this.longPressStartX;
    const dy = touch.screenY - this.longPressStartY;
    if (Math.hypot(dx, dy) > LONG_PRESS_MOVE_TOLERANCE) {
      this.cancelTouchTimer();
    }
  };

  private readonly cancelTouchTimer = (): void => {
    if (this.touchTimer) {
      clearTimeout(this.touchTimer);
      this.touchTimer = null;
    }
  };

  private readonly handleDelegatedPointerEnter = (event: Event): void => {
    if (!(event instanceof PointerEvent)) return;
    if (!(event.target instanceof HTMLElement)) return;

    // Only show tooltip on actual mouse hover, not touch
    if (event.pointerType !== 'mouse') return;

    const contentElement = event.target.querySelector(
      '[data-tooltip-target="html"]',
    );
    if (!(contentElement instanceof HTMLElement)) return;

    this.showTooltip(event.target, contentElement.innerHTML, contentElement);
  };

  private readonly handleDelegatedPointerLeave = (event: Event): void => {
    if (!(event instanceof PointerEvent)) return;
    if (!(event.target instanceof HTMLElement)) return;
    if (!event.target.querySelector('[data-tooltip-target="html"]')) return;

    // Only hide on mouse leave, not on touch end
    if (event.pointerType !== 'mouse') return;

    this.hide();
  };

  private readonly handleOverlayClick = (): void => {
    this.hide();
  };

  private readonly show = async (): Promise<void> => {
    if (this.isVisible) return;

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
    TooltipController.setActiveTooltip(this);

    this.updateTooltipContent(content);
    this.isVisible = true;

    await this.showTooltipAt(target, this.effectivePlacement);

    // Check if controller was disconnected during async operation
    if (!this.isVisible) return;

    if (observeElement) {
      this.observeContentChanges(observeElement);
    }

    this.createOverlay();
  }

  readonly hide = (): void => {
    if (!this.isVisible) return;

    this.isVisible = false;
    this.openedByTouch = false;
    TooltipController.releaseActiveTooltip(this);

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
    // Only create overlay for touch interactions, not for mouse hover
    if (!this.openedByTouch) return;
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

  private get tooltip(): HTMLElement {
    return TooltipController.shared().tooltip;
  }

  private get tooltipContent(): HTMLElement {
    return TooltipController.shared().content;
  }

  private get arrowElement(): HTMLElement {
    return TooltipController.shared().arrow;
  }

  /**
   * Builds the one tooltip element with arrow, on first use
   * Note: Does not append to DOM yet - that happens in ensureTooltipInCorrectContainer()
   */
  private static shared(): SharedTooltip {
    if (TooltipController.sharedTooltip) return TooltipController.sharedTooltip;

    const tooltip = document.createElement('div');
    tooltip.className = 'floating-tooltip';

    // The inner element carries the box and the show animation. It is kept
    // apart from the outer element because Floating UI measures the outer one,
    // and a transform would falsify that measurement (see the stylesheet).
    const inner = document.createElement('div');
    inner.className = 'floating-tooltip-inner';
    tooltip.appendChild(inner);

    const content = document.createElement('div');
    content.className = 'floating-tooltip-content';
    inner.appendChild(content);

    const arrowElement = document.createElement('div');
    arrowElement.className = 'floating-tooltip-arrow';
    inner.appendChild(arrowElement);

    TooltipController.sharedTooltip = { tooltip, content, arrow: arrowElement };

    return TooltipController.sharedTooltip;
  }

  /**
   * Ensures the tooltip is in the correct container (dialog or root element)
   * Called before showing the tooltip to handle dynamic dialog opening
   */
  private ensureTooltipInCorrectContainer(): void {
    const openDialog = document.querySelector('dialog[open]');

    // The root element, not `body`: Turbo replaces the body on every visit and
    // drops what a script appended to it. A child of the root element is left
    // where it is, and so is the fade it is in the middle of. That is what
    // lets one controller hand the box to the next.
    const desiredParent = openDialog || document.documentElement;

    // Append to correct parent if not already there
    if (this.tooltip.parentElement !== desiredParent) {
      desiredParent.appendChild(this.tooltip);
    }
  }

  /**
   * Updates the tooltip content, preserving the arrow element
   */
  private updateTooltipContent(content: string): void {
    this.tooltipContent.innerHTML = content;
  }

  /**
   * Shows the tooltip at the specified target element
   */
  private async showTooltipAt(
    target: HTMLElement,
    placement: Placement = 'bottom',
  ): Promise<void> {
    // Ensure tooltip is in correct container (dialog or root element)
    this.ensureTooltipInCorrectContainer();

    // The stylesheet limits the width of a tooltip that stands beside its
    // target. It reads the side that was asked for, not the one flip() picked,
    // because a width that reacts to the result changes the result.
    this.tooltip.dataset.side = placement.split('-')[0];

    // Cleanup existing position watcher before creating a new one
    this.positionCleanup?.();
    this.positionCleanup = null;

    await this.updateTooltipPosition(target, placement);

    // The line above waits, and this controller can go away while it does.
    // The element is shared, so a `show` and a watcher left behind here would
    // act on the tooltip of whoever comes next.
    if (!this.isVisible) return;

    this.tooltip.classList.add('show');

    // `layoutShift` reports every move of the target, and a press is such a
    // move: `click-animation` scales the target to 95%, which lifts the edge
    // the tooltip hangs on by a pixel, and the tooltip would follow. A tooltip
    // is open while the pointer rests on its target, and a target does not
    // travel on its own in that moment, so nothing is lost. Scrolling and
    // resizing still reposition the tooltip.
    this.positionCleanup = autoUpdate(
      target,
      this.tooltip,
      () => this.updateTooltipPosition(target, placement),
      { layoutShift: false },
    );
  }

  /**
   * Hides the tooltip and stops position updates
   */
  private hideTooltip(): void {
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

    // The stylesheet takes it from here: the placement below decides which of
    // the two coordinates the arrow follows, and how far it stands outside
    // the box.
    if (middlewareData.arrow) {
      const { x: arrowX, y: arrowY } = middlewareData.arrow;

      if (arrowX !== undefined) {
        this.tooltip.style.setProperty('--arrow-x', `${arrowX}px`);
      }
      if (arrowY !== undefined) {
        this.tooltip.style.setProperty('--arrow-y', `${arrowY}px`);
      }
    }

    this.tooltip.dataset.placement = actualPlacement;
  }

  private get effectivePlacement(): Placement {
    if (
      this.mobilePlacementValue &&
      window.matchMedia('(max-width: 767px)').matches
    )
      return this.mobilePlacementValue as Placement;

    return this.placementValue;
  }

  private supportsHover(): boolean {
    return window.matchMedia('(hover: hover)').matches;
  }

  private static setActiveTooltip(controller: TooltipController): void {
    if (
      TooltipController.activeTooltip &&
      TooltipController.activeTooltip !== controller
    ) {
      TooltipController.activeTooltip.hide();
    }
    TooltipController.activeTooltip = controller;
  }

  private static releaseActiveTooltip(controller: TooltipController): void {
    if (TooltipController.activeTooltip === controller) {
      TooltipController.activeTooltip = null;
    }
  }
}

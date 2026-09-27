import { Controller } from '@hotwired/stimulus';

// A swipe to the right goes back when it moves this far (px), and less far
// up or down than to the side
const SWIPE_BACK_DISTANCE = 60;

/**
 * The heatmap of the insights as a second page in the sheet, in the manner of
 * a navigation push on iOS. On a phone, a row pushes it in from the right,
 * and the back button or a swipe to the right takes it out again. A larger
 * screen shows the heatmap in the list (component.css), so nothing calls
 * this controller there.
 */
export default class extends Controller<HTMLElement> {
  static readonly targets = ['subpage'];

  declare readonly subpageTarget: HTMLElement;
  declare readonly hasSubpageTarget: boolean;

  private opener: HTMLElement | null = null;
  private swipeStartX: number | null = null;
  private swipeStartY = 0;

  push(event: Event): void {
    this.opener =
      event.currentTarget instanceof HTMLElement ? event.currentTarget : null;
    this.subpageTarget.classList.add('is-open');
    // The page takes the focus, not its back button: a ring around the
    // button would stand out after a tap. Tab reaches the button next.
    this.subpageTarget.focus({ preventScroll: true });
  }

  // The row takes the focus again, but shows its ring only after the
  // keyboard. The browser cannot tell: the focus before came from a script,
  // and a tap on iOS focuses nothing. A click from the keyboard has no count
  // (detail 0).
  pop(event?: Event): void {
    this.popTo(event instanceof MouseEvent ? event.detail === 0 : undefined);
  }

  private popTo(focusVisible?: boolean): void {
    this.subpageTarget.classList.remove('is-open');
    this.opener?.focus({ preventScroll: true, focusVisible });
    this.opener = null;
  }

  // Escape and the back gesture of Android cancel the dialog. With the page
  // open, they go back to the list, as the back button does, and the sheet
  // stays. The action listens in the capture phase on the document, so it
  // runs before the sheet (utils/bottomSheet.ts) and can stop the event. A
  // cancel that the browser does not let the page prevent closes the sheet.
  back(event: Event): void {
    // A sensor without a heatmap has no page
    if (!this.hasSubpageTarget) return;
    if (!this.subpageTarget.classList.contains('is-open')) return;
    if (event.target !== this.element.closest('dialog')) return;
    if (!event.cancelable) return;

    event.preventDefault();
    event.stopPropagation();
    this.pop();
  }

  swipeStart(event: PointerEvent): void {
    if (event.pointerType === 'mouse') return;

    this.swipeStartX = event.clientX;
    this.swipeStartY = event.clientY;
  }

  swipeEnd(event: PointerEvent): void {
    if (this.swipeStartX === null) return;

    const dx = event.clientX - this.swipeStartX;
    const dy = Math.abs(event.clientY - this.swipeStartY);
    this.swipeStartX = null;

    if (dx > SWIPE_BACK_DISTANCE && dx > dy) this.popTo(false);
  }
}

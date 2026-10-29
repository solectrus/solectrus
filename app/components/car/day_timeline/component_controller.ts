import { Controller } from '@hotwired/stimulus';
import type TooltipController from '@/controllers/tooltip_controller';

// A finger that moves along the row of the state of charge (see
// Car::DayTimeline::Component) shows the tooltip of the piece of the line
// below it, as the mouse does. The box stands above the row with its arrow at
// the finger, so the finger does not cover it, and it goes when the finger
// lifts. A tap still opens the sheet of a piece, and a move up or down
// scrolls the page.

// The finger moves this far to the side before the row takes it, so a tap
// stays a tap
const SCRUB_THRESHOLD = 8;

export default class extends Controller<HTMLElement> {
  private startX: number | null = null;
  private x = 0;
  private scrubbing = false;
  private piece: HTMLElement | null = null;

  // The place of the finger, over the full height of the row. It is read on
  // each update, so the box stays at the row while the page scrolls.
  private readonly reference = {
    getBoundingClientRect: () => {
      const row = this.element.getBoundingClientRect();
      return new DOMRect(this.x, row.top, 0, row.height);
    },
    contextElement: this.element,
  };

  disconnect() {
    this.end();
  }

  start(event: PointerEvent) {
    if (event.pointerType === 'mouse') return;

    this.startX = event.clientX;
    this.scrubbing = false;
  }

  move(event: PointerEvent) {
    if (this.startX === null) return;

    this.scrubbing ||= Math.abs(event.clientX - this.startX) >= SCRUB_THRESHOLD;
    if (!this.scrubbing) return;

    const { left, right } = this.element.getBoundingClientRect();
    this.x = Math.min(Math.max(event.clientX, left), right);
    this.select(this.pieceAt(this.x));
    if (this.piece) void this.tooltipOf(this.piece)?.follow(this.reference);
  }

  end() {
    this.startX = null;
    this.select(null);
  }

  // The click at the end of a move is no tap, so it opens no sheet
  click(event: Event) {
    if (!this.scrubbing) return;

    event.preventDefault();
    event.stopPropagation();
    this.scrubbing = false;
  }

  // The piece below the finger lights up as on a hover, and the one before
  // it takes its tooltip down
  private select(piece: HTMLElement | null) {
    if (piece === this.piece) return;

    if (this.piece) {
      this.piece.classList.remove('bg-fill');
      this.tooltipOf(this.piece)?.hide();
    }
    piece?.classList.add('bg-fill');
    this.piece = piece;
  }

  // The pieces of the line are the bars with a tooltip in the row
  private pieceAt(x: number): HTMLElement | null {
    const pieces = this.element.querySelectorAll<HTMLElement>(
      ':scope > [data-controller~="tooltip"]',
    );

    return (
      Array.from(pieces).find((piece) => {
        const { left, right } = piece.getBoundingClientRect();
        return x >= left && x <= right;
      }) ?? null
    );
  }

  private tooltipOf(piece: HTMLElement): TooltipController | null {
    return this.application.getControllerForElementAndIdentifier(
      piece,
      'tooltip',
    ) as TooltipController | null;
  }
}

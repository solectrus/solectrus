import { hasUnsavedChanges } from '@/utils/unsavedChanges';

// Behavior of a sheet (BottomSheet::Component): open and close with an
// animation, and close on a swipe down, on a tap beside the panel, on the
// close button and on Escape. A swipe leaves a form with unsaved changes
// open, as iOS does. The stylesheet beside the component decides how it
// looks and moves.

// Below this width the sheet sits on the lower edge and a swipe moves it.
// From md on it stands in the middle as a dialog, without a swipe. A tooltip
// that a touch opens becomes a sheet only there.
export const COMPACT_QUERY = '(max-width: 767px)';

// A swipe closes the sheet when it moves the panel this far (px) ...
const CLOSE_DISTANCE = 80;
// ... or when the finger leaves faster than this (px per ms)
const CLOSE_VELOCITY = 0.5;
// A long-press opens a sheet while the finger still rests on the screen.
// The lift of that finger must not count as a tap beside the panel.
const TAP_GUARD_MS = 400;
// Fallback for a transitionend that never comes (hidden tab, no transition)
const CLOSE_TIMEOUT_MS = 500;

const OPEN_CLASS = 'is-open';
const INSTANT_CLASS = 'is-instant';

// A drag that starts on one of these is an input, not a swipe. A link or a
// button may start a swipe, as on iOS, where a whole page can be links.
const FORM_FIELD = 'input, select, textarea';
// A drag further than this (px) is no tap: a click this soon (ms) after it
// must not follow a link
const TAP_SLOP = 10;
const CLICK_AFTER_DRAG_MS = 300;

// Areas that scroll on their own: the content, and an area inside it that
// covers it, like a second page. Each gets `is-scrollable` while it
// overflows, and the stylesheet gives it the vertical pan only then.
const SCROLL_AREA = '.bottom-sheet-content, .bottom-sheet-scroll';
// Where a drag moves the panel even over an area that scrolls
const HANDLE = '.bottom-sheet-header, [data-bottom-sheet-handle]';

interface BottomSheetOptions {
  // Runs once the sheet is closed and its animation is over
  onClosed?: () => void;
  // Escape asks this first. `false` keeps the sheet open, so an element
  // inside can take the key.
  canCancel?: () => boolean;
}

export class BottomSheet {
  readonly panel: HTMLElement;
  readonly content: HTMLElement;

  private state: 'closed' | 'open' | 'closing' = 'closed';
  private cancelClose: (() => void) | null = null;
  private openedAt = 0;
  private readonly resizeObserver: ResizeObserver;

  private dragStartY: number | null = null;
  // A form with unsaved changes: the panel only gives, it does not close
  private dragLocked = false;
  private dragLastY = 0;
  private dragLastTime = 0;
  private dragVelocity = 0;
  private dragMoved = false;
  private dragEndedAt = -Infinity;

  constructor(
    readonly dialog: HTMLDialogElement,
    private readonly options: BottomSheetOptions = {},
  ) {
    const panel = dialog.querySelector<HTMLElement>('.bottom-sheet-panel');
    const content = dialog.querySelector<HTMLElement>('.bottom-sheet-content');
    if (!panel || !content) throw new Error('Sheet markup incomplete');

    this.panel = panel;
    this.content = content;

    dialog.addEventListener('click', this.handleClick);
    dialog.addEventListener('cancel', this.handleCancel);
    panel.addEventListener('pointerdown', this.startDrag);
    panel.addEventListener('pointermove', this.moveDrag);
    panel.addEventListener('pointerup', this.endDrag);
    panel.addEventListener('pointercancel', this.endDrag);
    panel.addEventListener('click', this.swallowClickAfterDrag, true);

    // The content can grow or shrink while the sheet is open
    this.resizeObserver = new ResizeObserver(() => this.markScrollable());
    for (const area of panel.querySelectorAll(SCROLL_AREA))
      this.resizeObserver.observe(area);
  }

  // `instant` skips the fade of the dim area, for a backdrop that is on the
  // screen already
  open({ instant = false } = {}): void {
    if (this.state === 'open') return;

    // Sliding out: turn around, the dialog is still in the top layer
    if (this.state === 'closing') {
      this.cancelClose?.();
      this.state = 'open';
      this.dialog.classList.add(OPEN_CLASS);
      return;
    }

    this.state = 'open';
    this.panel.style.transform = '';
    this.dialog.classList.toggle(INSTANT_CLASS, instant);
    this.dialog.showModal();
    this.focusPanelInsteadOfClose();
    this.openedAt = performance.now();
    this.markScrollable();

    // One frame in the closed state first, so the panel slides in
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        if (this.state === 'open') this.dialog.classList.add(OPEN_CLASS);
      });
    });
  }

  close(): void {
    if (this.state !== 'open') return;

    this.state = 'closing';
    this.dialog.classList.remove(INSTANT_CLASS);
    this.panel.style.transition = '';
    this.panel.style.transform = '';
    this.dialog.classList.remove(OPEN_CLASS);

    const onTransitionEnd = (event: TransitionEvent) => {
      if (event.target === this.panel) finish();
    };
    const timer = setTimeout(() => finish(), CLOSE_TIMEOUT_MS);
    const stop = () => {
      clearTimeout(timer);
      this.panel.removeEventListener('transitionend', onTransitionEnd);
      this.cancelClose = null;
    };
    const finish = () => {
      stop();
      this.state = 'closed';
      this.dialog.close();
      this.options.onClosed?.();
    };

    // Opened again while it slides out: the timer and the listener of this
    // close must not end a later one
    this.cancelClose = stop;
    this.panel.addEventListener('transitionend', onTransitionEnd);
  }

  // The centered line above the content, with an optional detail below it.
  // An empty text hides it.
  setCaption(title: string, detail = ''): void {
    const titleElement = this.dialog.querySelector(
      '.bottom-sheet-caption-title',
    );
    const detailElement = this.dialog.querySelector(
      '.bottom-sheet-caption-detail',
    );
    if (titleElement) titleElement.textContent = title;
    if (detailElement) detailElement.textContent = detail;
  }

  // showModal() focuses the first element with autofocus, else the first
  // focusable one: the close button. With a hardware keyboard (as in the iOS
  // Simulator) that focus counts as focus-visible, and the button hidden on a
  // phone shows up. The panel takes that focus instead. On a phone, Tab also
  // passes the button by: it only serves a screen reader there.
  private focusPanelInsteadOfClose(): void {
    const closeButton = this.dialog.querySelector('.bottom-sheet-close');
    closeButton?.setAttribute(
      'tabindex',
      window.matchMedia(COMPACT_QUERY).matches ? '-1' : '0',
    );

    if (document.activeElement?.closest('.bottom-sheet-close')) {
      this.panel.focus({ preventScroll: true });
    }
  }

  // For content that changed while the sheet is open
  markScrollable(): void {
    for (const area of this.panel.querySelectorAll(SCROLL_AREA)) {
      area.classList.toggle(
        'is-scrollable',
        area.scrollHeight > area.clientHeight,
      );
    }
  }

  destroy(): void {
    this.resizeObserver.disconnect();
    this.dialog.removeEventListener('click', this.handleClick);
    this.dialog.removeEventListener('cancel', this.handleCancel);
    this.panel.removeEventListener('pointerdown', this.startDrag);
    this.panel.removeEventListener('pointermove', this.moveDrag);
    this.panel.removeEventListener('pointerup', this.endDrag);
    this.panel.removeEventListener('pointercancel', this.endDrag);
    this.panel.removeEventListener('click', this.swallowClickAfterDrag, true);
  }

  private readonly handleClick = (event: MouseEvent): void => {
    if (!(event.target instanceof Element)) return;

    if (event.target.closest('.bottom-sheet-close')) {
      this.close();
      return;
    }

    // The dialog covers the whole viewport and holds the panel, so a click on
    // the dialog itself is a click beside the panel
    if (event.target !== this.dialog) return;
    if (performance.now() - this.openedAt < TAP_GUARD_MS) return;

    this.close();
  };

  // Escape: animate instead of the instant close of the browser
  private readonly handleCancel = (event: Event): void => {
    event.preventDefault();
    if (this.options.canCancel?.() === false) return;

    this.close();
  };

  private readonly startDrag = (event: PointerEvent): void => {
    if (event.pointerType === 'mouse') return;
    if (this.state !== 'open') return;
    if (!window.matchMedia(COMPACT_QUERY).matches) return;
    if (!(event.target instanceof Element)) return;
    if (event.target.closest(FORM_FIELD)) return;

    // An area that scrolls keeps its vertical pan. There, only a handle, like
    // the header, drags the panel.
    const area = event.target.closest(SCROLL_AREA);
    if (
      area?.classList.contains('is-scrollable') &&
      !event.target.closest(HANDLE)
    )
      return;

    this.dragStartY = event.clientY;
    this.dragLocked = hasUnsavedChanges(this.content);
    this.dragLastY = event.clientY;
    this.dragLastTime = event.timeStamp;
    this.dragVelocity = 0;
    this.dragMoved = false;
    this.panel.style.transition = 'none';
    // No pointer capture: a touch stays with the element it started on
    // anyway, and the moves bubble up to the panel. A capture on the panel
    // would take the click away from a link that the finger only tapped.
  };

  private readonly moveDrag = (event: PointerEvent): void => {
    if (this.dragStartY === null) return;

    const delta = event.clientY - this.dragStartY;
    if (Math.abs(delta) > TAP_SLOP) this.dragMoved = true;
    // Upwards, and with unsaved changes also downwards, the panel only gives
    // a little, like a rubber band
    const offset = delta > 0 && !this.dragLocked ? delta : delta / 5;
    this.panel.style.transform = `translateY(${offset}px)`;

    const elapsed = event.timeStamp - this.dragLastTime;
    if (elapsed > 0)
      this.dragVelocity = (event.clientY - this.dragLastY) / elapsed;
    this.dragLastY = event.clientY;
    this.dragLastTime = event.timeStamp;
  };

  private readonly endDrag = (event: PointerEvent): void => {
    if (this.dragStartY === null) return;

    const delta = event.clientY - this.dragStartY;
    this.dragStartY = null;
    if (this.dragMoved) this.dragEndedAt = event.timeStamp;

    if (
      event.type === 'pointerup' &&
      !this.dragLocked &&
      (delta > CLOSE_DISTANCE || this.dragVelocity > CLOSE_VELOCITY)
    ) {
      this.close();
      return;
    }

    // Back to the resting position
    this.panel.style.transition = '';
    this.panel.style.transform = '';
  };

  // A drag that started on a link and moved the panel is no tap. Should the
  // lift of the finger still cause a click, it must not follow the link.
  private readonly swallowClickAfterDrag = (event: MouseEvent): void => {
    if (event.timeStamp - this.dragEndedAt > CLICK_AFTER_DRAG_MS) return;

    this.dragEndedAt = -Infinity;
    event.preventDefault();
    event.stopPropagation();
  };
}

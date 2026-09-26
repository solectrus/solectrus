import { BottomSheet } from '@/utils/bottomSheet';

// The sheet that stands in for a tooltip on a phone. The layout renders it
// once, empty and permanent (BottomSheet::Component with this id). A
// tooltip puts its content in and learns when the sheet closes, whatever
// closed it.

const ID = 'tooltip-sheet';

let sheet: BottomSheet | null = null;
let onClose: (() => void) | null = null;

export function isTooltipSheetAvailable(): boolean {
  return find() !== null;
}

export function openTooltipSheet(html: string, handleClose: () => void): void {
  const current = find();
  if (!current) return;

  // The new content takes the sheet over, also one that slides out. Its
  // former tooltip hid already (setActiveTooltip of the tooltip controller).
  onClose = handleClose;

  updateTooltipSheet(html);
  current.open();
}

export function updateTooltipSheet(html: string): void {
  const current = find();
  if (!current) return;

  current.content.innerHTML = html;
  current.markScrollable();
}

export function closeTooltipSheet(): void {
  find()?.close();
}

function find(): BottomSheet | null {
  if (sheet?.dialog.isConnected) return sheet;

  const dialog = document.getElementById(ID);
  if (!(dialog instanceof HTMLDialogElement)) return null;

  sheet?.destroy();
  sheet = new BottomSheet(dialog, {
    onClosed: () => {
      dialog.querySelector('.bottom-sheet-content')?.replaceChildren();

      const callback = onClose;
      onClose = null;
      callback?.();
    },
  });
  return sheet;
}

// A visit replaces the page below the sheet, so its content has no target
// anymore. data-turbo-permanent keeps the element, so it must be closed here.
document.addEventListener('turbo:before-visit', closeTooltipSheet);

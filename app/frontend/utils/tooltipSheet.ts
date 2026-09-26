import { BottomSheet } from '@/utils/bottomSheet';

// The sheet that stands in for a tooltip on a phone. The layout renders it
// once, empty and permanent (BottomSheet::Component with this id). A
// tooltip puts its content in and learns when the sheet closes, whatever
// closed it.

const ID = 'tooltip-sheet';

// What the content belongs to, like the period of a figure
interface Context {
  title: string;
  detail: string;
}

let sheet: BottomSheet | null = null;
let onClose: (() => void) | null = null;
let context: Context = { title: '', detail: '' };

export function isTooltipSheetAvailable(): boolean {
  return find() !== null;
}

export function openTooltipSheet(
  target: HTMLElement,
  html: string,
  handleClose: () => void,
): void {
  const current = find();
  if (!current) return;

  // The new content takes the sheet over, also one that slides out. Its
  // former tooltip hid already (setActiveTooltip of the tooltip controller).
  onClose = handleClose;

  context = findContext(target);
  updateTooltipSheet(html);
  current.open();
}

// A tooltip can name its own context (data-sheet-caption), like the version
// in the menu. Otherwise the sheet covers the navigation that names the
// period of the figures, so it repeats the period. Only a figure of the page
// belongs to that period: a tooltip outside of <main> has none. A page
// without a period has no context.
function findContext(target: HTMLElement): Context {
  const caption = target.closest<HTMLElement>('[data-sheet-caption]')?.dataset
    .sheetCaption;
  if (caption) return { title: caption, detail: '' };

  const navigation = target.closest('main')
    ? document.querySelector<HTMLElement>('[data-timeframe-label]')
    : null;
  return {
    title: navigation?.dataset.timeframeLabel ?? '',
    detail: navigation?.dataset.timeframeDates ?? '',
  };
}

// Content with a title shows the context below it in gray, as the insights
// of a segment do. Without a title, the caption above the content names it.
function showContext(sheet: BottomSheet): void {
  const title = sheet.content.querySelector(
    '.tooltip-heading > .tooltip-title',
  );
  if (title && context.title) {
    const period = document.createElement('p');
    period.className = 'tooltip-period';
    period.textContent = context.title;
    title.after(period);
    sheet.setCaption('');
    return;
  }

  sheet.setCaption(context.title, context.detail);
}

export function updateTooltipSheet(html: string): void {
  const current = find();
  if (!current) return;

  current.content.innerHTML = html;
  showContext(current);
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

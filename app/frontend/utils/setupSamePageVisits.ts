// Marks a visit to the page that is already open, like the reload after a
// build or the morph after a logout. On a phone, a visit hides the content
// until the next page renders (see application.css). A visit to the same page
// is no answer to a tap, so its content stays in view.
//
// A link with `data-same-page` leads to the open page with another filter,
// like a chip of the cars (see Ui::Chips::Component). Its visit counts as one
// to the same page too, so the content does not blink away and back.
//
// The mark lasts from turbo:visit to turbo:load. The URL of the open page
// comes from its last turbo:load, because Turbo may push the new URL before
// turbo:visit.
export function setupSamePageVisits() {
  const { dataset } = document.documentElement;
  let openUrl = location.href;
  let filterClick = false;

  document.addEventListener('turbo:click', (event) => {
    const link = event.target as Element | null;
    filterClick = link?.matches?.('[data-same-page]') ?? false;
  });

  document.addEventListener('turbo:visit', (event) => {
    const { url } = (event as CustomEvent<{ url: string }>).detail;
    if (url === openUrl || filterClick) dataset.navSamePage = '';
    filterClick = false;
  });

  document.addEventListener('turbo:load', () => {
    openUrl = location.href;
    delete dataset.navSamePage;
  });
}

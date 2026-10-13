import { cache, StreamActions, visit } from '@hotwired/turbo';
import { isEntryBefore } from '@/utils/historyTrail';

// The way back from the page of a form to its list, after a save or a delete
// (see FormPageResponse). The stream action back_to names the list.
//
// When the entry before the form in the history is that list, the browser
// goes back to it, as the back button of iOS does. So the form leaves the
// history, and a later way back does not lead to the list a second time. The
// list slides in from the left (see Ui::TitleBar::Component). Turbo loads it
// again instead of showing its snapshot, which is old now. Without such an
// entry, like after a reload of the form, a visit to the list replaces the
// form.
export function setupBackTo() {
  StreamActions.back_to = function (this: Element) {
    const target = this.getAttribute('target');
    if (!target) return;

    const url = new URL(target, location.href);
    if (isEntryBefore(url)) {
      cache.clear();
      history.back();
    } else {
      visit(url.href, { action: 'replace' });
    }
  };
}

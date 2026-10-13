// The path of each entry of the history, under the index that Turbo gives the
// entry. The history does not tell the URL of another entry. So the way back
// with the back button of Ui::TitleBar::Component looks here whether the entry
// before is the parent. Only then can it go back in the history, else it
// visits the parent.
//
// The trail lives in the session storage, so it survives a reload of the tab.
//
// The index is internal to Turbo, not part of its API. The system specs of
// the phone layout guard it.
const KEY = 'history-trail';

type Trail = Record<number, string>;

let memory: Trail = {};

function readTrail(): Trail {
  try {
    return JSON.parse(sessionStorage.getItem(KEY) ?? '{}') as Trail;
  } catch {
    return memory;
  }
}

function writeTrail(trail: Trail) {
  memory = trail;
  try {
    sessionStorage.setItem(KEY, JSON.stringify(trail));
  } catch {
    // Without storage the trail lives in memory, until the next reload
  }
}

function currentIndex(): number | undefined {
  return (history.state as { turbo?: { restorationIndex?: number } } | null)
    ?.turbo?.restorationIndex;
}

// The path and the query, in a form that two links to the same page share:
// the parameters sorted by key, a key with brackets as the key without, and
// no empty values. So `?category=a` and `?category[]=a` name one list.
function pathOf(url: URL | Location | HTMLAnchorElement) {
  const params = [...new URLSearchParams(url.search)]
    .filter(([, value]) => value !== '')
    .map(([key, value]) => [key.replace(/\[\]$/, ''), value])
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  const search = new URLSearchParams(params).toString();
  return search ? `${url.pathname}?${search}` : url.pathname;
}

export function setupHistoryTrail() {
  document.addEventListener('turbo:load', () => {
    const index = currentIndex();
    if (index === undefined) return;

    // An entry after this one comes back with its own turbo:load, so the
    // trail keeps only the entries up to this one and does not grow
    const trail: Trail = {};
    for (const [key, path] of Object.entries(readTrail())) {
      if (Number(key) < index) trail[Number(key)] = path;
    }
    trail[index] = pathOf(location);
    writeTrail(trail);
  });
}

// Whether the entry before this one in the history shows the given URL
export function isEntryBefore(url: URL | HTMLAnchorElement) {
  const index = currentIndex();
  return !!index && readTrail()[index - 1] === pathOf(url);
}

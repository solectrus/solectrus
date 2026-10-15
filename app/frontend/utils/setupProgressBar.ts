import * as Turbo from '@hotwired/turbo';

type BrowserAdapter = {
  visitProgressBarTimeout?: number;
  showVisitProgressBarAfterDelay?: () => void;
};

// A visit shows the progress bar after a delay, by a timeout. A second visit
// that starts before the first one has ended, like a second tap on a
// timeframe arrow, cancels the first one. Turbo then sets the timeout of the
// second visit and forgets the one of the first visit without clearing it.
// When the second visit ends before that delay, the forgotten timeout still
// shows the bar, and nothing hides it until the next visit. So a new timeout
// clears the one before.
export function setupProgressBar() {
  const adapter = Turbo.session.adapter as BrowserAdapter;
  const showAfterDelay = adapter.showVisitProgressBarAfterDelay?.bind(adapter);
  if (!showAfterDelay) return;

  adapter.showVisitProgressBarAfterDelay = () => {
    clearTimeout(adapter.visitProgressBarTimeout);
    showAfterDelay();
  };
}

import { Application } from '@hotwired/stimulus';
import { registerControllers } from 'stimulus-vite-helpers';
import type { TurboFrameMissingEvent } from '@hotwired/turbo';
import * as Turbo from '@hotwired/turbo';

// Start Stimulus application
export const application = Application.start();

// Configure Stimulus development experience
application.debug = false; // process.env.NODE_ENV === 'development';

// Load and register global controllers
registerControllers(
  application,
  import.meta.glob('../controllers/*_controller.{js,ts}', { eager: true }),
);

// Load and register view_components controllers
registerControllers(
  application,
  import.meta.glob('../../components/**/*_controller.{js,ts}', { eager: true }),
);

// Show progress bar immediately on navigation (default: 500ms delay)
Turbo.config.drive.progressBarDelay = 0;

// A morph refresh (turbo_refreshes_with :morph) to the same URL - e.g. after a
// logout that redirects back to the current page - rewinds lazily-loaded
// content frames (charts, tiles) to their server-rendered spinner placeholder.
// Their `src` is unchanged, so Turbo never re-fetches them and they stay stuck
// on the spinner. Reload every src-driven frame after a morph so its content
// comes back.
//
// Frames marked `data-turbo-permanent` are preserved by the morph (their live
// content survives untouched), so reloading them would be pure waste - e.g. the
// live "now" page's stats frame. Skip them.
document.addEventListener('turbo:morph', () => {
  document
    .querySelectorAll<Turbo.FrameElement>(
      'turbo-frame[src]:not([data-turbo-permanent])',
    )
    .forEach((frame) => frame.reload());
});

// Error handling for missing Turbo frames
document.addEventListener('turbo:frame-missing', (event) => {
  const {
    detail: { response },
  } = event as TurboFrameMissingEvent;
  event.preventDefault();
  window.location.href = response.url;
});

Turbo.StreamActions.redirect = function (this: Element) {
  const target = this.getAttribute('target');
  if (target) {
    Turbo.visit(target);
  }
};

Turbo.StreamActions.update_all = function (this: Element) {
  const selector = this.getAttribute('targets');

  if (selector) {
    const content = this.querySelector('template')?.innerHTML?.trim() || '';
    document.querySelectorAll(selector).forEach((el) => {
      if (content) {
        el.innerHTML = content;
      } else {
        el.remove();
      }
    });
  }
};

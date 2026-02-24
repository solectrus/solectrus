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

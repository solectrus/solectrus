import { Application } from '@hotwired/stimulus';
import { registerControllers } from 'stimulus-vite-helpers';
import * as Turbo from '@hotwired/turbo';
import type { TurboFrameMissingEvent } from '@hotwired/turbo';
import morphdom from 'morphdom';

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

// Setup "morph" as custom Turbo.StreamAction
Turbo.StreamActions.morph = function (this) {
  const options = {
    childrenOnly: this.hasAttribute('children-only'),

    // https://github.com/patrick-steele-idem/morphdom#can-i-make-morphdom-blaze-through-the-dom-tree-even-faster-yes
    onBeforeElUpdated: (fromEl: Element, toEl: Element) =>
      !fromEl.isEqualNode(toEl),
  };

  this.targetElements.forEach((element) => {
    morphdom(
      element,
      options.childrenOnly
        ? this.templateContent
        : this.templateElement.innerHTML,
      options,
    );
  });
};

// Error handling for missing Turbo frames
document.addEventListener('turbo:frame-missing', (event) => {
  const {
    detail: { response },
  } = event as TurboFrameMissingEvent;
  event.preventDefault();
  window.location.href = response.url;
});

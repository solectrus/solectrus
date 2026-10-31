import { Controller } from '@hotwired/stimulus';

// The labels of the parts of a bar (see Car::ShareBar::Component). Each part
// has the forms of its label from long to short, and shows the longest form
// that fits its width, or none. The width changes with the window and once
// the font loads. A refresh of the figures morphs the bar and hides the
// forms again, so each of these fits the labels anew.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['segment'];

  declare readonly segmentTargets: HTMLElement[];

  private observer?: ResizeObserver;
  private frame = 0;

  connect() {
    this.observer = new ResizeObserver(this.schedule);
    this.observer.observe(this.element);
    this.element.addEventListener('turbo:morph-element', this.schedule);
    void document.fonts.ready.then(this.schedule);
  }

  disconnect() {
    this.observer?.disconnect();
    this.element.removeEventListener('turbo:morph-element', this.schedule);
    cancelAnimationFrame(this.frame);
  }

  private readonly schedule = () => {
    cancelAnimationFrame(this.frame);
    this.frame = requestAnimationFrame(() => this.fit());
  };

  // Each round shows the next form of each part that does not fit yet, then
  // measures all of them at once, so a round costs one layout
  private fit() {
    let open = this.segmentTargets.map((segment) => {
      const forms = Array.from(segment.children) as HTMLElement[];
      for (const form of forms) form.hidden = true;
      return { segment, forms };
    });

    for (let index = 0; open.length > 0; index++) {
      for (const { forms } of open) {
        if (index > 0) forms[index - 1]!.hidden = true;
        if (forms[index]) forms[index].hidden = false;
      }
      open = open.filter(
        ({ segment, forms }) =>
          forms[index] && segment.scrollWidth > segment.clientWidth,
      );
    }
  }
}

import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller {
  static readonly values = {
    url: String,
    frame: String,
    action: String,
  };

  declare readonly urlValue: string;
  declare readonly frameValue: string;
  declare readonly actionValue: string;

  declare readonly hasFrameValue: boolean;
  declare readonly hasActionValue: boolean;

  connect() {
    this.element.addEventListener('click', this.handleClick);
  }

  disconnect() {
    this.element.removeEventListener('click', this.handleClick);
  }

  handleClick = (event: Event) => {
    const target = event.target as HTMLElement | null;
    if (target?.closest('a')) return;

    Turbo.visit(this.urlValue, {
      frame: this.hasFrameValue ? this.frameValue : undefined,
      action: this.hasActionValue ? this.actionValue : undefined,
    });
  };
}

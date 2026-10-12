import { Controller, type ActionEvent } from '@hotwired/stimulus';
import { writeCookie } from '@/utils/cookie';

// A phone shows one of the two cards of the car page, the charging or the
// driving. The server renders the choice from a cookie, also when a refresh
// morphs the stats. So a tap switches the cards here at once, and the cookie
// keeps the choice for the next render.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['charging', 'driving', 'button'];

  declare readonly chargingTarget: HTMLElement;
  declare readonly drivingTarget: HTMLElement;
  declare readonly buttonTargets: HTMLButtonElement[];

  show(event: ActionEvent) {
    const card = String(event.params.card);

    this.chargingTarget.classList.toggle('max-sm:hidden', card !== 'charging');
    this.drivingTarget.classList.toggle('max-sm:hidden', card !== 'driving');
    this.buttonTargets.forEach((button) =>
      button.setAttribute(
        'aria-pressed',
        String(button.dataset.carCardsCardParam === card),
      ),
    );

    // The default needs no cookie
    writeCookie('car_card', card === 'driving' ? card : null);
  }
}

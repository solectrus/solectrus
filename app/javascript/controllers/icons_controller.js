import { Controller } from '@hotwired/stimulus';
import { config, library, dom } from '@fortawesome/fontawesome-svg-core';

// ------------------------- Add new icons here
import { faChevronLeft } from '@fortawesome/free-solid-svg-icons/faChevronLeft';
import { faChevronRight } from '@fortawesome/free-solid-svg-icons/faChevronRight';

import { faTimes } from '@fortawesome/free-solid-svg-icons/faTimes';
import { faSun } from '@fortawesome/free-solid-svg-icons/faSun';
import { faHome } from '@fortawesome/free-solid-svg-icons/faHome';
import { faCar } from '@fortawesome/free-solid-svg-icons/faCar';
import { faPlug } from '@fortawesome/free-solid-svg-icons/faPlug';

import { faBatteryEmpty } from '@fortawesome/free-solid-svg-icons/faBatteryEmpty';
import { faBatteryQuarter } from '@fortawesome/free-solid-svg-icons/faBatteryQuarter';
import { faBatteryHalf } from '@fortawesome/free-solid-svg-icons/faBatteryHalf';
import { faBatteryThreeQuarters } from '@fortawesome/free-solid-svg-icons/faBatteryThreeQuarters';
import { faBatteryFull } from '@fortawesome/free-solid-svg-icons/faBatteryFull';

import { faArrowRightToBracket } from '@fortawesome/free-solid-svg-icons/faArrowRightToBracket';
import { faArrowRightFromBracket } from '@fortawesome/free-solid-svg-icons/faArrowRightFromBracket';

import { faGithub } from '@fortawesome/free-brands-svg-icons/faGithub';
// -------------------------

export default class extends Controller {
  initialize() {
    config.autoAddCss = false;

    // Fix flash of missing icons
    config.mutateApproach = 'sync';

    library.add(
      faSun,
      faHome,
      faCar,
      faPlug,
      faChevronLeft,
      faChevronRight,
      faTimes,
      faBatteryEmpty,
      faBatteryQuarter,
      faBatteryHalf,
      faBatteryThreeQuarters,
      faBatteryFull,
      faArrowRightToBracket,
      faArrowRightFromBracket,
      faGithub,
    );
  }

  connect() {
    dom.watch();
  }
}

import { Controller } from '@hotwired/stimulus';
import { config, library, dom } from '@fortawesome/fontawesome-svg-core';

// ------------------------- Add new icons here
import { faChevronLeft } from '@fortawesome/free-solid-svg-icons/faChevronLeft';
import { faChevronRight } from '@fortawesome/free-solid-svg-icons/faChevronRight';

import { faArrowDownWideShort } from '@fortawesome/free-solid-svg-icons/faArrowDownWideShort';
import { faArrowDownShortWide } from '@fortawesome/free-solid-svg-icons/faArrowDownShortWide';
import { faRotateLeft } from '@fortawesome/free-solid-svg-icons/faRotateLeft';

import { faPlus } from '@fortawesome/free-solid-svg-icons/faPlus';
import { faPencil } from '@fortawesome/free-solid-svg-icons/faPencil';
import { faTrash } from '@fortawesome/free-solid-svg-icons/faTrash';
import { faTimes } from '@fortawesome/free-solid-svg-icons/faTimes';

import { faSun } from '@fortawesome/free-solid-svg-icons/faSun';
import { faHome } from '@fortawesome/free-solid-svg-icons/faHome';
import { faCar } from '@fortawesome/free-solid-svg-icons/faCar';
import { faPlug } from '@fortawesome/free-solid-svg-icons/faPlug';
import { faBolt } from '@fortawesome/free-solid-svg-icons/faBolt';
import { faFan } from '@fortawesome/free-solid-svg-icons/faFan';

import { faBatteryEmpty } from '@fortawesome/free-solid-svg-icons/faBatteryEmpty';
import { faBatteryQuarter } from '@fortawesome/free-solid-svg-icons/faBatteryQuarter';
import { faBatteryHalf } from '@fortawesome/free-solid-svg-icons/faBatteryHalf';
import { faBatteryThreeQuarters } from '@fortawesome/free-solid-svg-icons/faBatteryThreeQuarters';
import { faBatteryFull } from '@fortawesome/free-solid-svg-icons/faBatteryFull';

import { faArrowRightToBracket } from '@fortawesome/free-solid-svg-icons/faArrowRightToBracket';
import { faArrowRightFromBracket } from '@fortawesome/free-solid-svg-icons/faArrowRightFromBracket';

import { faGithub } from '@fortawesome/free-brands-svg-icons/faGithub';
import { faCog } from '@fortawesome/free-solid-svg-icons/faCog';
import { faCircleCheck } from '@fortawesome/free-regular-svg-icons/faCircleCheck';
import { faCircleQuestion } from '@fortawesome/free-solid-svg-icons/faCircleQuestion';
import { faCircleInfo } from '@fortawesome/free-solid-svg-icons/faCircleInfo';
import { faCircleExclamation } from '@fortawesome/free-solid-svg-icons/faCircleExclamation';

import { faIdCard } from '@fortawesome/free-solid-svg-icons/faIdCard';
import { faPiggyBank } from '@fortawesome/free-solid-svg-icons/faPiggyBank';
import { faLeaf } from '@fortawesome/free-solid-svg-icons/faLeaf';
import { faCompress } from '@fortawesome/free-solid-svg-icons/faCompress';
import { faExpand } from '@fortawesome/free-solid-svg-icons/faExpand';

import { faGrip } from '@fortawesome/free-solid-svg-icons/faGrip';
import { faTrophy } from '@fortawesome/free-solid-svg-icons/faTrophy';
import { faHouseCrack } from '@fortawesome/free-solid-svg-icons/faHouseCrack';
import { faSolarPanel } from '@fortawesome/free-solid-svg-icons/faSolarPanel';

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
      faBolt,
      faFan,
      faChevronLeft,
      faChevronRight,
      faArrowDownWideShort,
      faArrowDownShortWide,
      faRotateLeft,
      faPlus,
      faPencil,
      faTrash,
      faTimes,
      faBatteryEmpty,
      faBatteryQuarter,
      faBatteryHalf,
      faBatteryThreeQuarters,
      faBatteryFull,
      faArrowRightToBracket,
      faArrowRightFromBracket,
      faGithub,
      faCog,
      faCircleCheck,
      faCircleQuestion,
      faCircleExclamation,
      faCircleInfo,
      faIdCard,
      faPiggyBank,
      faLeaf,
      faCompress,
      faExpand,
      faHouseCrack,
      faSolarPanel,
      faGrip,
      faTrophy,
    );
  }

  connect() {
    dom.watch();
  }
}

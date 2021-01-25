import { Controller } from 'stimulus'
import { config, library, dom } from '@fortawesome/fontawesome-svg-core'

// ------------------------- Add new icons here
import { faChevronLeft }          from '@fortawesome/free-solid-svg-icons/faChevronLeft'
import { faChevronRight }         from '@fortawesome/free-solid-svg-icons/faChevronRight'

import { faSun }                  from '@fortawesome/free-solid-svg-icons/faSun'
import { faHome }                 from '@fortawesome/free-solid-svg-icons/faHome'
import { faCar }                  from '@fortawesome/free-solid-svg-icons/faCar'
import { faPlug }                 from '@fortawesome/free-solid-svg-icons/faPlug'
import { faMoneyBillAlt }         from '@fortawesome/free-solid-svg-icons/faMoneyBillAlt'

import { faBatteryEmpty }         from '@fortawesome/free-solid-svg-icons/faBatteryEmpty'
import { faBatteryQuarter }       from '@fortawesome/free-solid-svg-icons/faBatteryQuarter'
import { faBatteryHalf }          from '@fortawesome/free-solid-svg-icons/faBatteryHalf'
import { faBatteryThreeQuarters } from '@fortawesome/free-solid-svg-icons/faBatteryThreeQuarters'
import { faBatteryFull }          from '@fortawesome/free-solid-svg-icons/faBatteryFull'
// -------------------------

export default class extends Controller {
  initialize() {
    // Fix flash of missing icons
    config.mutateApproach = 'sync'

    library.add(
      faSun,
      faHome,
      faCar,
      faPlug,
      faChevronLeft,
      faChevronRight,
      faBatteryEmpty,
      faBatteryQuarter,
      faBatteryHalf,
      faBatteryThreeQuarters,
      faBatteryFull,
      faMoneyBillAlt
    )
  }

  connect() {
    dom.watch({
      autoReplaceSvgRoot: this.element,
      observeMutationsRoot: this.element
    })
  }
}

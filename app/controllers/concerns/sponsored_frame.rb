# The gate of a frame that carries the data of a home page.
#
# A frame is a request of its own, so what holds the page back has to hold the
# frame back as well. Six things decide, and they are the six the page
# reads: the settings can switch the page off (see
# Sensor::HomePage.available?), the page can be a sponsor feature (see
# Sensor::HomePage.permitted?), the sensor can be one as well, even on a page
# that is free, a chart of the car page belongs to the car page alone, a
# relative timeframe is a sponsor feature on every page, and the page can
# have no hours view (see Sensor::HomePage.hours?).
module SponsoredFrame
  extend ActiveSupport::Concern

  included do
    before_action :verify_sponsoring

    private

    def verify_sponsoring
      return if permitted_page? && permitted_sensor? && own_sensor? && permitted_timeframe? && offered_timeframe?

      head :not_found
    end

    # The namespace of the controller is the key of the page, for all five of
    # them: Balance, Cars, Heatpump, House and Inverter.
    def frame_page_key
      helpers.controller_namespace.to_sym
    end

    def permitted_page?
      Sensor::HomePage.open?(frame_page_key)
    end

    # Only the permission, not whether the installation has the sensor: a page
    # can default to a sensor it lacks (see Heatpump::HomeController), and its
    # frame then draws an empty chart. A frame without a sensor has nothing to
    # hold back.
    def permitted_sensor?
      sensor.nil? || !Sensor::Config.withheld?(sensor.name)
    end

    # A chart of the car page answers only in a frame of the car page. That
    # frame ends the data of a visitor with the latest public day (see
    # Car::AdminOnlyDays), a frame of another page would draw it in full.
    def own_sensor?
      !sensor.is_a?(Sensor::Definitions::CarPageChart) || frame_page_key == :cars
    end

    def permitted_timeframe?
      !timeframe&.relative? || ApplicationPolicy.relative_timeframe?
    end

    def offered_timeframe?
      !timeframe&.hours? || Sensor::HomePage.hours?(frame_page_key)
    end
  end
end

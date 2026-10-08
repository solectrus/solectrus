# The gate of a frame that carries the data of a home page.
#
# A frame is a request of its own, so what holds the page back has to hold the
# frame back as well. Four things decide, and they are the four the page
# reads: the settings can switch the page off (see
# Sensor::HomePage.available?), the page can be a sponsor feature (see
# Sensor::HomePage.permitted?), a relative timeframe is one on every page,
# and the page can have no hours view (see Sensor::HomePage.hours?).
module SponsoredFrame
  extend ActiveSupport::Concern

  included do
    before_action :verify_sponsoring

    private

    def verify_sponsoring
      return if permitted_page? && permitted_timeframe? && offered_timeframe?

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

    def permitted_timeframe?
      !timeframe&.relative? || ApplicationPolicy.relative_timeframe?
    end

    def offered_timeframe?
      !timeframe&.hours? || Sensor::HomePage.hours?(frame_page_key)
    end
  end
end

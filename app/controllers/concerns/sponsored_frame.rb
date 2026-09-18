# The gate of a frame that carries the data of a home page.
#
# A frame is a request of its own, so what holds the page back has to hold the
# frame back as well. Two things decide, and they are the two the page reads:
# the page can be a sponsor feature (see Sensor::HomePage.permitted?), and a
# relative timeframe is one on every page.
module SponsoredFrame
  extend ActiveSupport::Concern

  included do
    before_action :verify_sponsoring

    private

    def verify_sponsoring
      return if permitted_page? && permitted_timeframe?

      head :not_found
    end

    # The namespace of the controller is the key of the page, for all four of
    # them: Balance, Heatpump, House and Inverter.
    def permitted_page?
      Sensor::HomePage.permitted?(helpers.controller_namespace.to_sym)
    end

    def permitted_timeframe?
      !timeframe&.relative? || ApplicationPolicy.relative_timeframe?
    end
  end
end

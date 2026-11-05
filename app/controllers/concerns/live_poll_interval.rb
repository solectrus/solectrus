# The live view of a home page polls its stats at the rate of the data (see
# Influx::PollInterval). The page gets that rate once, when it renders, but the
# rate changes: an outage of the collector raises it to the maximum, the
# return of the data lowers it again. So every stats answer of the live view
# carries the current rate, and the page adopts it (see
# StatsWithChart::Component).
module LivePollInterval
  extend ActiveSupport::Concern

  # The Stimulus controller of StatsWithChart::Component reads it by this name
  HEADER = 'X-Poll-Interval'.freeze
  public_constant :HEADER

  included do
    after_action :send_poll_interval, if: -> { timeframe&.now? }

    private

    def send_poll_interval
      response.set_header(HEADER, Influx::PollInterval.current.to_i.to_s)
    end
  end
end

module Sensor
  module Definitions
    # A chart on the car page alone. It has no scalar value, and the car
    # page needs the sponsorship. A chart with a trend takes its value from
    # the report of the cars (see Car::Report#value).
    module CarPageChart
      extend ActiveSupport::Concern

      included do
        home_pages :cars

        chart_only

        requires_permission :car
      end
    end
  end
end

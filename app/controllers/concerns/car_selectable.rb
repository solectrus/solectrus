# The selection of a car on the car page. The route of a page has a place for
# the sensor and the timeframe alone, so the car is a parameter (?car=2).
# Without it, the page shows "all": the sum of the cars, and not the sum of
# the wallbox, because a wallbox session without a car counts for no car.
#
# An id without a car selects "all". With one car, "all" is that car, and the
# page offers no select.
module CarSelectable
  extend ActiveSupport::Concern

  included do
    private

    # All cars of the installation, for the select
    helper_method def all_cars
      @all_cars ||= Car::Provisioning.call.to_a
    end

    # The selected car, or nil for "all"
    helper_method def car
      return @car if defined?(@car)

      car_id = Integer(params[:car], exception: false)
      @car = all_cars.find { it.id == car_id }
    end

    # The cars the page shows
    helper_method def cars
      car ? [car] : all_cars
    end

    # The parameter each link of the page keeps
    helper_method def car_param
      car&.id&.to_s
    end

    # Each link of the page keeps the car: the timeframe navigation, the chart
    # selector and the addresses of the frames. "all" needs no parameter.
    def default_url_options
      car_param ? super.merge(car: car_param) : super
    end
  end
end

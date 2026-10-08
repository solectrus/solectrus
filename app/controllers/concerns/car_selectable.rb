# The selection of a car on the car page (see CarSelection). With more than
# one car in the installation, the page offers a select, also for a timeframe
# with one car or none. With one car, "all" is that car, and the page offers
# no select.
module CarSelectable
  extend ActiveSupport::Concern

  included do
    private

    helper_method def car_selection
      @car_selection ||= CarSelection.new(params[:car], timeframe:)
    end

    # The selected car, or nil for "all"
    helper_method def car = car_selection.car

    # The cars the page shows
    helper_method def cars = car_selection.cars

    # Each link of the car page keeps the car: the timeframe navigation, the
    # chart selector and the addresses of the frames. Each car also gets a
    # stats frame of its own (see ApplicationHelper#scoped_frame_id). The
    # car stays also as nil for "all", because Rails takes a missing car
    # from the current address.
    def selection_params = { car: car_selection.to_param }

    # Each chart of the car page shows the selected cars
    def chart_options = { cars: }
  end
end

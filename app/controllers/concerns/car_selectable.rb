# The selection of a car or of the guest sessions on the car page (see
# CarSelection). With more than one car in the installation or with guest
# sessions, the page offers a select, also for a timeframe with one car or
# none (see #car_select?). Otherwise "all" is the one car, and the page
# offers no select.
module CarSelectable
  extend ActiveSupport::Concern

  included do
    private

    helper_method def car_selection
      @car_selection ||= CarSelection.new(params[:car], timeframe:, guest: true)
    end

    helper_method def car_select?
      car_selection.installed.many? || car_selection.guest_offered?
    end

    # The select of the page. Its choices keep the chart, so a chart that
    # loads in place renders it again (see the charts of the cars).
    helper_method def car_select_component(**)
      Car::Select::Component.new(cars: car_selection.offered, car:, guest: car_selection.guest_offered?, guest_selected: car_selection.guest?, **)
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

    # The live view shows each car in use and selects none (see
    # CarSelection#car). It has no select, so with a select in the
    # installation, its link to another timeframe takes the one car in use
    # there, otherwise "all". The guest sessions are rare, so the one car
    # leaves them out.
    def timeframe_selection_params(target)
      return { car: nil } if target == 'now'
      return selection_params unless timeframe&.now? && car_select?

      offered = CarSelection.new(nil, timeframe: Timeframe.new(target)).offered
      { car: (offered.first.id.to_s if offered.one?) }
    end

    # Each chart of the car page shows the selected cars, and the guest
    # sessions for the guest and for "all". Only the admin sees the places of
    # a car.
    def chart_options = { cars:, guest: car_selection.with_guest?, admin: admin? }
  end
end

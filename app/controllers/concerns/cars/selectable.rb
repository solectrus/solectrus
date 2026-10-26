# The selection of a car or of the guest sessions on the car page (see
# CarSelection). With more than one car in the installation or with guest
# sessions, the page offers a select, also for a timeframe with one car or
# none (see #car_select?). Otherwise "all" is the one car, and the page
# offers no select.
module Cars::Selectable
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

    # Whether the day is one that a guest does not see (see Car::AdminOnlyDays)
    helper_method def admin_only_day? = !admin? && timeframe.present? && Car::AdminOnlyDays.cover?(timeframe)

    # Whether a longer period of a guest leaves out such days, because its
    # data ends with the latest public day (see #data_timeframe)
    helper_method def admin_only_days_left_out?
      !admin? && timeframe.present? && !timeframe.now? && !timeframe.day? && Car::AdminOnlyDays.overlap?(timeframe)
    end

    # The timeframe of the data: the report, the charts and the spans. A
    # guest sees the data of a period up to the latest public day (see
    # Timeframe#max_date). The navigation keeps the timeframe of the address,
    # so the day of a guest is still today, with its note.
    helper_method def data_timeframe
      @data_timeframe ||=
        if admin? || timeframe.nil? || timeframe.now?
          timeframe
        else
          Car::AdminOnlyDays.public_timeframe(timeframe)
        end
    end

    # The columns of the overview of the car page (see Car::Section). A
    # selected car with an odometer drives, and the guest only charges.
    helper_method def overview_sections
      cars.any? { it.sensor?(:car_odometer) } ? Car::Section.all : [:charging]
    end

    # The charts of each column (see Car::Section::CHARTS) that draw the
    # timeframe and the selection, none for a period without charts (see
    # Car::Section.charts?)
    helper_method def section_charts
      @section_charts ||= overview_sections.index_with do |section|
        next [] if timeframe && !Car::Section.charts?(timeframe)

        Car::Section::CHARTS[section].select do
          Sensor::HomePage.accepts?(:cars, it) && Sensor::Registry[it].chart(timeframe, **chart_options)&.supported? != false
        end
      end
    end

    # The columns with a chart
    helper_method def chart_sections = section_charts.select { |_, charts| charts.any? }.keys

    # Whether the column has no value in the period
    helper_method def idle_section?(section) = !Car::Section.value?(section, section_report)

    # The report of the period that the columns ask before the figures load
    def section_report
      @section_report ||= Car::Report.new(data_timeframe, cars, guest: car_selection.with_guest?)
    end

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
    # sessions for the guest and for "all"
    def chart_options = { cars:, guest: car_selection.with_guest? }
  end
end

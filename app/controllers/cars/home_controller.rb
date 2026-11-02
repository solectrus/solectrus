# The car page. Its live view shows each car. A period shows the figures of
# the charging and of the driving (see Car::Section), and one chart beside
# them, which a click on a figure or a pick of the menu changes. The sensor
# of the chart is in the address: /cars/2/2025, /cars/2/car_cost_rate/2025.
# A day has its timeline in the place of the chart.
class Cars::HomeController < HomePageController
  include Cars::Selectable

  private

  def page_key = :cars

  # Whether the page has anything to show: the odometer of a car, for the
  # driving cost and the rates, or its state of charge, for the live view and
  # the charging
  helper_method def stats?
    Sensor::Config.exists?(:car_driving_costs) || Sensor::Cars.numbered(:car_battery_soc).any?
  end

  # A period without charts, the live view and a day, has no sensor in its
  # address (see Car::Section.charts?). A period without a sensor shows the
  # first chart of each column. A chart that cannot draw the timeframe or the
  # selection goes to the first chart of each column, too.
  def supported_sensor?
    return true if sensor_name.nil?
    return false if (timeframe && !Car::Section.charts?(timeframe)) || Car::Section.of(sensor_name).nil?

    super
  end

  def default_sensor_name = nil

  # A period without charts has no sensor in its address: /cars/now,
  # /cars/2026-06-26. The timeframe can come as text, like "day" for today.
  def path_for(name, keep_timeframe = nil)
    keep = keep_timeframe.is_a?(String) ? Timeframe.new(keep_timeframe) : keep_timeframe
    super((name if keep && Car::Section.charts?(keep)), keep_timeframe)
  end

  # The car page has no forecast, so a future timeframe goes back to now.
  def future_path = path_for(nil)

  # A car that the page does not offer goes to "all", for example a car
  # outside its period in the live view
  def offered_selection? = car_selection.valid?

  # The rates per 100 km read a window around each day of the period, so the
  # days of these windows need summaries and a detection, too
  def load_missing_or_stale_summary_days(timeframe)
    return super if timeframe.now?

    @missing_or_stale_summary_days = Sensor::Summarizer.build_few(Car::Report.pending_days(timeframe))
  end

  # The chart of the page: the chart of the address, else the first chart
  # of its column, else of the first column with a value, like the charging
  # of a week without a drive (see Cars::Selectable#section_charts). Nil
  # without a chart. A chart of the address that the period cannot draw stays
  # in the address, so it comes back with the next timeframe.
  helper_method def chart_name
    section = Car::Section.of(sensor_name).presence_in(chart_sections) || chart_sections.find { !idle_section?(it) } || chart_sections.first
    charts = section_charts.fetch(section, [])
    charts.find { it.to_s == sensor_name.to_s } || charts.first
  end
end

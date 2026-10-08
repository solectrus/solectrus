class Cars::HomeController < HomePageController
  include CarSelectable

  private

  def page_key = :cars

  # The distance, because a car drives on more days than it charges. The
  # charged energy where the timeframe has no chart of the distance, for
  # example for a car without an odometer.
  DEFAULT_SENSOR_NAMES = %i[car_distance car_charging].freeze
  private_constant :DEFAULT_SENSOR_NAMES

  def default_sensor_name
    @default_sensor_name ||= (DEFAULT_SENSOR_NAMES.find { supported_chart?(it) } if timeframe) || DEFAULT_SENSOR_NAMES.first
  end

  # The live view has no chart, so its address has no sensor: /cars/now (see
  # Sensor::HomePage.live_chart?)
  def supported_sensor?
    timeframe&.now? ? sensor_name.nil? : super
  end

  def path_for(name, keep_timeframe = nil)
    super((name unless keep_timeframe.nil? || keep_timeframe.try(:now?)), keep_timeframe)
  end

  # The links of the live view go to the first default chart. Its check
  # needs the target timeframe, so the rare chart that does not support it
  # redirects there.
  def chart_sensor_name = sensor_name || DEFAULT_SENSOR_NAMES.first

  # The car page has no forecast, so a future timeframe goes back to now.
  def future_path = path_for(nil)

  # A car that the page does not offer goes to "all", for example a car
  # outside its period in the live view
  def offered_selection? = car_selection.valid?

  # The rates per 100 km read a window around each day of the period, so the
  # days of these windows need summaries and a detection, too
  def load_missing_or_stale_summary_days(timeframe)
    return super if timeframe.now?

    @missing_or_stale_summary_days = Car::Report.pending_days(timeframe)
  end
end

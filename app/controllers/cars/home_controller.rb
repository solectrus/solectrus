class Cars::HomeController < HomePageController
  include CarSelectable

  private

  def page_key = :cars

  def default_sensor_name = :car_charging

  # The car page has no forecast, so a future timeframe goes back to now.
  def future_path = path_for(sensor_name)

  # A rate chart needs buckets of a day at least, and the range chart draws a
  # day at most. Any other timeframe goes to the default chart instead, which
  # keeps the timeframe.
  def supported_sensor?
    return false unless super

    timeframe.nil? || Sensor::Registry[sensor_name].chart(timeframe).supported?
  end

  # The rates per 100 km read a window around each day of the period, so the
  # days of these windows need summaries, too (see Car::DailyRates). The energy
  # and the cost come from the charging sessions, so a day needs its
  # detection as well.
  def load_missing_or_stale_summary_days(timeframe)
    return super if timeframe.now? || timeframe.hours?

    @missing_or_stale_summary_days = Car::DailyRates.new(timeframe, cars).missing_or_stale_days
  end
end

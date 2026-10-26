# The two columns of the overview of the car page: the driving and the
# charging, in the order of the timeline of a day. Each column shows its
# figures and the chart of one of them. The sensor of the chart in the
# address chooses the chart of its column (/cars/2/car_cost_rate/2025), and
# the other column shows its first chart. A chart without a value draws its
# empty axes.
module Car::Section
  # The charts of each column, in the order of the menu, the first chart first
  CHARTS = {
    driving: %i[car_distance car_driving_costs car_cost_rate car_consumption_rate car_max_range],
    charging: %i[car_charging car_charging_costs car_battery_soc],
  }.freeze
  public_constant :CHARTS

  def self.all = CHARTS.keys

  # Whether a period shows the charts of its columns. The live view has none,
  # and a day has the timeline of the day in their place (see
  # Car::DayTimeline::Component).
  def self.charts?(timeframe) = !(timeframe.now? || timeframe.day?)

  # The column of the chart, or nil
  def self.of(sensor_name) = CHARTS.find { |_, charts| charts.include?(sensor_name&.to_sym) }&.first

  # Whether the column has a value in the period of the report (see
  # Car::Report): a charging session, or a drive
  def self.value?(section, report) = section == :charging ? report.charged? : report.driven?
end

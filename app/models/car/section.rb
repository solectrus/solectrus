# The two columns of the overview of the car page: the charging and the
# driving. Each column shows its figures and the chart of one of them. The
# sensor of the chart in the address chooses the chart of its column
# (/cars/2/car_cost_rate/2025), and the other column shows its first chart.
# A chart without a value draws its empty axes.
module Car::Section
  # The charts of each column, in the order of the menu, the first chart first
  CHARTS = {
    charging: %i[car_charging car_charging_costs car_battery_soc],
    driving: %i[car_distance car_driving_costs car_cost_rate car_consumption_rate car_max_range car_range],
  }.freeze
  public_constant :CHARTS

  def self.all = CHARTS.keys

  # The column of the chart, or nil
  def self.of(sensor_name) = CHARTS.find { |_, charts| charts.include?(sensor_name&.to_sym) }&.first

  # Whether the column has a value in the period of the report (see
  # Car::Report): a charging session, or a drive
  def self.value?(section, report) = section == :charging ? report.charged? : report.driven?
end

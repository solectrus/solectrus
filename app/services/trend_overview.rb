# The trends of a home page at a glance (TrendOverview::Component), the
# first page of the sheet of the insights. Each row stands for a sensor of
# the page and leads to its insights. There are two kinds:
#
# - TrendOverview::Changes for a month or a year: the change of each sensor
#   against an earlier period
# - TrendOverview::Years for the whole time: the value of each sensor in
#   each year
#
# The car page takes its values from the report of its cars
# (Car::ChangesOverview, Car::YearsOverview).
#
# A sensor that nets two directions, like the grid, shows its two parts
# instead, because the net value hides what each part did.
class TrendOverview
  PARTS = {
    grid_power: %i[grid_import_power grid_export_power],
    battery_power: %i[battery_charging_power battery_discharging_power],
  }.freeze
  private_constant :PARTS

  # The groups in the order of the overview. The car page groups by the
  # columns of the page (Car::Section).
  GROUPS = %i[driving charging generation consumption heat grid_battery finance quotas averages].freeze
  public_constant :GROUPS

  # The order of the rows within a group: the total first, then from the
  # source of the energy to its use, like the balance. A sensor without a
  # place, like a consumer or a string of the inverter, follows by name.
  ROW_ORDER = %i[
    inverter_power
    total_consumption
    house_power
    heatpump_power
    wallbox_power
    heatpump_heating_power
    grid_import_power
    grid_export_power
    battery_charging_power
    battery_discharging_power
    grid_revenue
    grid_costs
    savings
    total_costs
    heatpump_costs
    autarky
    self_consumption_quote
    battery_soc
    heatpump_cop
    outdoor_temp
    heatpump_tank_temp
    case_temp
  ].freeze
  private_constant :ROW_ORDER

  # The sensors that sum up the rows below them in their group, like the
  # house consumption its consumers
  TOTALS = %i[inverter_power total_consumption house_power].freeze
  private_constant :TOTALS

  # Units whose values read as a difference, not as a share: a temperature
  # has no true zero, and the efficiency of the heat pump reads as a number
  # of its own
  DIFFERENCE_UNITS = %i[celsius unitless].freeze
  private_constant :DIFFERENCE_UNITS

  # Whether the sheet of the insights of this sensor opens with the
  # overview: the permission shows it, the page has one for the period, and
  # the sensor is one of the page or has a row in the overview, like a part
  # of the grid
  def self.available?(page:, sensor:, timeframe:)
    ApplicationPolicy.trends? && page_period?(page:, timeframe:) && overview_names(page).include?(sensor.name)
  end

  # Whether the page has an overview for the period: a month or a year past
  # its first day, which has no earlier period to compare with yet, or the
  # whole time. A visitor of the car page sees fewer days (see
  # Car::AdminOnlyDays), so the period also needs two days it shows.
  # Without the permission, the button beside the timeframe opens a teaser
  # in its place (see TrendsController).
  def self.page_period?(page:, timeframe:)
    return false if Sensor::HomePage.all.exclude?(page.to_sym)
    return true if timeframe.all?
    return false unless timeframe.month_like? || timeframe.year_like?

    timeframe.days_passed > 1 && timeframe.effective_dates.count > 1
  end

  # The overview of a page. `car` is the selection of the car page (see
  # CarSelection).
  def self.build(page:, timeframe:, base:, car: nil)
    cars = page.to_sym == :cars
    if timeframe.all?
      cars ? Car::YearsOverview.new(timeframe:, car:) : Years.new(page:, timeframe:)
    else
      cars ? Car::ChangesOverview.new(timeframe:, base:, car:) : Changes.new(page:, timeframe:, base:)
    end
  end

  # The earlier periods a timeframe compares with. A year has no other
  # period than the year before.
  def self.bases(timeframe)
    timeframe.month_like? ? Trend::BASES : %i[previous_year]
  end

  # The earlier period that a parameter names, the year before by default
  def self.base_for(timeframe, param)
    bases(timeframe).find { it.to_s == param.to_s } || :previous_year
  end

  # The parameter of an earlier period in a link, none for the default
  def self.base_param(base) = (base unless base == :previous_year)

  # Whether the sensor sums up the rows below it (see TOTALS)
  def self.total?(sensor) = TOTALS.include?(sensor.name)

  # The name of a row and of the insights below it. On its own page, the
  # heat pump stands for its electricity, as the page calls it beside a
  # name of its own (Heatpump::PowerCard::Component).
  def self.label(sensor, page:)
    page.to_sym == :heatpump && sensor.name == :heatpump_power ? I18n.t('sensors.heatpump_power_short') : sensor.display_name
  end

  # The sensors of the page and the parts of its net sensors, whose sheet
  # opens with the overview
  def self.overview_names(page)
    names = page_sensor_names(page.to_sym)
    names + names.flat_map { PARTS.fetch(it, []) }
  end

  # The sensors of the page that have a trend
  def self.page_sensor_names(page)
    Sensor::HomePage.sensor_names(page).select do |name|
      sensor = Sensor::Registry[name]
      sensor.trendable? && sensor.permitted?
    end
  end

  def initialize(page:, timeframe:)
    @page = page.to_sym
    @timeframe = timeframe
  end

  attr_reader :page, :timeframe

  # The parameters that each link of the overview keeps, like the earlier
  # period or the car of the car page
  def link_params = {}

  # The rows by group, in the order of GROUPS. Within a group, the rows keep
  # the order of the sensors (see ROW_ORDER).
  def groups
    @groups ||=
      rows.group_by { group_of(it.sensor) }.sort_by { |group, _| GROUPS.index(group) }.to_h
  end

  # One row for each sensor, built by the kind of the overview
  def rows = raise(NotImplementedError)

  private

  # The sensors of the rows, a net sensor as its parts, in the order of
  # ROW_ORDER. The order of the pages comes from the order in which the
  # sensors load, so it is no order to keep.
  def sensor_names
    @sensor_names ||=
      self.class.page_sensor_names(page)
        .flat_map { |name| PARTS[name]&.select { Sensor::Config.exists?(it) }.presence || [name] }
        .sort_by { [ROW_ORDER.index(it) || ROW_ORDER.size, Sensor::Registry[it].display_name] }
  end

  # The first day of each field of the rows, in one query
  def first_dates
    @first_dates ||= SummaryValue.first_dates(sensor_names.flat_map { Trend.summary_fields(Sensor::Registry[it]) }.uniq)
  end

  def group_of(sensor)
    if sensor.unit == :percent
      :quotas
    elsif sensor.unit.in?(DIFFERENCE_UNITS)
      :averages
    elsif sensor.unit == :money
      :finance
    else
      group_of_sum(sensor)
    end
  end

  def group_of_sum(sensor)
    case sensor.category
    when :inverter
      :generation
    when :grid, :battery
      :grid_battery
    when :heatpump
      :heat
    else
      :consumption
    end
  end
end

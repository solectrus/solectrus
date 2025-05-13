class PowerTop10
  def initialize(sensor:, desc:, calc:)
    @sensor = sensor
    @calc = ActiveSupport::StringInquirer.new(calc)
    @desc = desc
  end

  attr_reader :sensor, :calc, :desc

  def days
    top start: start(:day), stop: stop(:day), period: :day
  end

  def weeks
    top start: start(:week), stop: stop(:week), period: :week
  end

  def months
    top start: start(:month), stop: stop(:month), period: :month
  end

  def years
    top start: start(:year), stop: stop(:year), period: :year
  end

  private

  def start(period)
    raw = Rails.configuration.x.installation_date.beginning_of_day
    # In ascending order, the first period may not be included because it is (most likely) not complete
    adjustment = desc ? 0 : 1.public_send(period)

    (raw + adjustment).public_send(:"beginning_of_#{period}")
  end

  def stop(period)
    raw = Date.current.end_of_day
    # In ascending order, the current period may not be included because it is not yet complete
    adjustment = desc ? 0 : 1.public_send(period)

    (raw - adjustment).public_send(:"end_of_#{period}")
  end

  def excluded_sensor_names
    SensorConfig.x.excluded_sensor_names
  end

  def top(start:, stop:, period:, limit: 10)
    return [] unless SensorConfig.x.exists?(sensor)
    return [] if start > stop

    if sensor == :house_power && excluded_sensor_names.any?
      build_query_house_power(start:, stop:, period:, limit:)
    else
      build_query_simple(start:, stop:, period:, limit:)
    end
  end

  FIELD_MAPPING = {
    sum: {
      inverter_power: 'sum',
      heatpump_power: 'sum',
      house_power: 'sum',
      case_temp: 'avg',
      grid_import_power: 'sum',
      grid_export_power: 'sum',
      battery_charging_power: 'sum',
      battery_discharging_power: 'sum',
      wallbox_power: 'sum',
      **SensorConfig::CUSTOM_SENSORS.index_with { 'sum' },
    },
    max: {
      inverter_power: 'max',
      heatpump_power: 'max',
      house_power: 'max',
      case_temp: 'max',
      grid_import_power: 'max',
      grid_export_power: 'max',
      battery_charging_power: 'max',
      battery_discharging_power: 'max',
      wallbox_power: 'max',
    },
  }.freeze
  private_constant :FIELD_MAPPING

  def sort_order
    desc ? :desc : :asc
  end

  def build_query_simple(start:, stop:, period:, limit:)
    scope =
      SummaryValue.where(
        date: start..stop,
        field: sensor,
        aggregation: FIELD_MAPPING[calc.to_sym][sensor],
      ).limit(limit)
    scope = scope.where(SummaryValue.arel_table[:value].gt(0)) unless desc

    if period == :day
      # Just order by the sensor value
      scope
        .select(:value, :date)
        .order(value: sort_order)
        .map { |it| { date: it.date, value: it.value } }
    else
      # Group by period and calculate the sum of the sensor
      calculation = { 'sum' => :sum, 'max' => :maximum }[calc]

      scope
        .group_by_period(period, :date, series: false)
        .order("1 #{sort_order}")
        .calculate(calculation, :value)
        .map { |date, value| { date:, value: } }
        .sort_by { desc ? -it[:value] : it[:value] }
    end
  end

  def build_query_house_power(start:, stop:, period:, limit:)
    scope =
      SummaryValue.where(
        date: start..stop,
        field: ['house_power', *excluded_sensor_names],
        aggregation: 'sum',
      ).limit(limit)

    difference =
      "SUM(CASE WHEN field = 'house_power' THEN value ELSE 0 END) -
         SUM(CASE WHEN field != 'house_power' THEN value ELSE 0 END)
         AS difference"

    case period
    when :day
      scope
        .select(:date, difference)
        .group(:date)
        .order("difference #{sort_order}")
        .map { |it| { date: it.date, value: it.difference } }
    else
      scope
        .group_by_period(period, :date, series: false)
        .order("2 #{sort_order}")
        .calculate_all(difference)
        .map { |(date, value)| { date:, value: } }
        .sort_by { desc ? -it[:value] : it[:value] }
    end
  end
end

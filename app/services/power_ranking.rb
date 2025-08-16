class PowerRanking # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, desc:, calc:, limit: 10, from: nil, to: nil)
    @sensor = sensor
    @calc = ActiveSupport::StringInquirer.new(calc)
    @desc = desc
    @limit = limit

    if from && to && from > to
      raise ArgumentError, "From date #{from} cannot be after To date #{to}."
    end

    @from = from
    @to = to
  end

  attr_reader :sensor, :calc, :desc, :limit, :from, :to

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
    raw = (from || Rails.configuration.x.installation_date).beginning_of_day
    beginning_of_period = raw.public_send(:"beginning_of_#{period}")

    if desc ||
         (
           raw == beginning_of_period &&
             raw > Rails.configuration.x.installation_date.beginning_of_day
         )
      beginning_of_period
    else
      # Ascending and incomplete period: Start at the next period
      beginning_of_period + 1.public_send(period)
    end
  end

  def stop(period)
    raw = (to || Date.current).end_of_day
    end_of_period = raw.public_send(:"end_of_#{period}")

    if desc || (raw == end_of_period && raw < Date.current)
      end_of_period
    else
      # Ascending and incomplete period: Stop at the previous period
      end_of_period - 1.public_send(period)
    end
  end

  def excluded_sensor_names
    SensorConfig.x.excluded_sensor_names
  end

  def top(start:, stop:, period:)
    return [] unless SensorConfig.x.exists?(sensor)
    return [] if start > stop

    if sensor == :house_power && excluded_sensor_names.any?
      build_query_house_power(start:, stop:, period:)
    elsif sensor == :inverter_power && SensorConfig.x.multi_inverter?
      build_query_inverter_power(start:, stop:, period:)
    else
      build_query_simple(start:, stop:, period:)
    end
  end

  FIELD_MAPPING = {
    sum: {
      inverter_power: 'sum',
      **SensorConfig::CUSTOM_INVERTER_SENSORS.index_with { 'sum' },
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
      **SensorConfig::CUSTOM_INVERTER_SENSORS.index_with { 'max' },
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

  def build_query_simple(start:, stop:, period:)
    scope =
      SummaryValue.where(
        date: start..stop,
        field: sensor,
        aggregation: FIELD_MAPPING[calc.to_sym][sensor],
      ).limit(limit)
    scope = scope.where(SummaryValue.arel_table[:value].gt(10)) unless desc

    if period == :day
      # Just order by the sensor value
      scope
        .select(:value, :date)
        .order(value: sort_order)
        .map { { date: it.date, value: it.value } }
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

  def build_query_house_power(start:, stop:, period:)
    scope =
      SummaryValue.where(
        date: start..stop,
        field: ['house_power', *excluded_sensor_names],
        aggregation: 'sum',
      ).limit(limit)

    difference_calculation =
      "SUM(CASE WHEN field = 'house_power' THEN value ELSE 0 END) -
         SUM(CASE WHEN field != 'house_power' THEN value ELSE 0 END)"
    difference = "#{difference_calculation} AS difference"
    having_clause = "#{difference_calculation} > 0" unless desc

    case period
    when :day
      scope
        .select(:date, difference)
        .group(:date)
        .order("difference #{sort_order}")
        .having(having_clause)
        .map { { date: it.date, value: it.difference } }
    else
      scope
        .group_by_period(period, :date, series: false)
        .order("2 #{sort_order}")
        .having(having_clause)
        .calculate_all(difference)
        .map { |(date, value)| { date:, value: } }
        .sort_by { desc ? -it[:value] : it[:value] }
    end
  end

  def build_query_inverter_power(start:, stop:, period:)
    scope =
      SummaryValue.where(
        date: start..stop,
        field: inverter_power_fields,
        aggregation: FIELD_MAPPING[calc.to_sym][sensor],
      ).limit(limit)

    total = 'SUM(value) AS total'
    having_clause = 'SUM(value) > 0' unless desc

    if period == :day
      scope
        .group(:date)
        .select(:date, total)
        .order("total #{sort_order}")
        .having(having_clause)
        .map { { date: it.date, value: it.total } }
    else
      scope
        .group_by_period(period, :date, series: false)
        .order("2 #{sort_order}")
        .having(having_clause)
        .calculate_all(total)
        .map { |(date, value)| { date:, value: } }
        .sort_by { desc ? -it[:value] : it[:value] }
    end
  end

  def inverter_power_fields
    if SensorConfig.x.inverter_total_present?
      [:inverter_power]
    else
      SensorConfig.x.inverter_sensor_names
    end
  end
end

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

  def exclude_from_house_power
    SensorConfig.x.exclude_from_house_power
  end

  def top(start:, stop:, period:, limit: 10)
    return [] unless SensorConfig.x.exists?(sensor)
    return [] if start > stop

    if sensor == :house_power && exclude_from_house_power.any?
      build_query_house_power(start:, stop:, period:, limit:)
    else
      build_query_simple(start:, stop:, period:, limit:)
    end
  end

  FIELD_MAPPING_SUM = {
    car_driving_distance: :car_driving_distance,
    inverter_power: :sum_inverter_power,
    outdoor_temp: :avg_outdoor_temp,
    heatpump_power: :sum_heatpump_power,
    house_power: :sum_house_power,
    heatpump_heating_power: :sum_heatpump_heating_power,
    case_temp: :avg_case_temp,
    grid_import_power: :sum_grid_import_power,
    grid_export_power: :sum_grid_export_power,
    battery_charging_power: :sum_battery_charging_power,
    battery_discharging_power: :sum_battery_discharging_power,
    wallbox_power: :sum_wallbox_power,
    **SensorConfig::CUSTOM_SENSORS.index_with { |sensor| :"sum_#{sensor}" },
  }.freeze
  private_constant :FIELD_MAPPING_SUM

  FIELD_MAPPING_MAX = {
    car_driving_distance: :car_driving_distance,
    inverter_power: :max_inverter_power,
    outdoor_temp: :max_outdoor_temp,
    heatpump_power: :max_heatpump_power,
    house_power: :max_house_power,
    heatpump_heating_power: :max_heatpump_heating_power,
    case_temp: :max_case_temp,
    grid_import_power: :max_grid_import_power,
    grid_export_power: :max_grid_export_power,
    battery_charging_power: :max_battery_charging_power,
    battery_discharging_power: :max_battery_discharging_power,
    wallbox_power: :max_wallbox_power,
  }.freeze
  private_constant :FIELD_MAPPING_MAX

  def build_query_simple(start:, stop:, period:, limit:)
    scope =
      Summary.where(date: start..stop).where(
        Summary.arel_table[:"#{FIELD_MAPPING_SUM[sensor]}"].gt(0),
      )

    sort_order = desc ? :desc : :asc

    sensor_column =
      case calc
      when 'sum'
        FIELD_MAPPING_SUM[sensor]
      when 'max'
        FIELD_MAPPING_MAX[sensor]
      end

    case period
    when :day
      # Just order by the sensor value
      scope
        .select(:date, sensor_column)
        .order("#{sensor_column} #{sort_order}")
        .limit(limit)
        .map do |record|
          { date: record.date, value: record.public_send(sensor_column) }
        end
    else
      # Group by period and calculate the sum of the sensor
      scope
        .group_by_period(period, :date)
        .order("2 #{sort_order}")
        .limit(limit)
        .calculate_all("#{calc}(#{sensor_column})")
        .map { |record| { date: record.first, value: record.second } }
    end
  end

  def build_query_house_power(start:, stop:, period:, limit:)
    scope = Summary.where(date: start..stop).where('sum_house_power > 0')
    sort_order = desc ? :desc : :asc

    total_column =
      "sum_house_power#{exclude_from_house_power.map { |sensor_to_exclude| " - COALESCE(sum_#{sensor_to_exclude}, 0)" }.join}"

    case period
    when :day
      scope
        .select(:date, "#{total_column} AS total")
        .order("2 #{sort_order}")
        .limit(limit)
        .map { |record| { date: record.date, value: record.total } }
    else
      total_column_sum = "SUM(#{total_column})"

      scope
        .group_by_period(period, :date)
        .order("2 #{sort_order}")
        .limit(limit)
        .calculate_all(total_column_sum)
        .map { |record| { date: record.first, value: record.second } }
    end
  end
end

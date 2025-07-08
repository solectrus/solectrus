class Insights::Heatmap < Insights::Base
  def initialize(sensor:, timeframe:)
    super(timeframe:)
    @sensor = sensor
  end

  attr_reader :sensor

  def call
    return unless timeframe.all?
    return if sensor.blank?

    build_data
  end

  private

  def build_data
    # Get all monthly data for the sensor
    data = fetch_data

    # Group by year and month
    years = data.group_by { it[:year] }

    # Build the heatmap structure
    heatmap = {}
    years.each do |year, months|
      heatmap[year] = {}
      months.each do |month_data|
        month = month_data[:month]
        value = month_data[:value]
        heatmap[year][month] = value
      end
    end

    heatmap
  end

  def fetch_data
    case sensor
    when :house_power
      fetch_house_power_data
    when :inverter_power
      fetch_inverter_power_data
    when :grid_power
      fetch_grid_power_data
    when :battery_power
      fetch_standard_data(:battery_discharging_power)
    else
      fetch_standard_data
    end
  end

  def fetch_standard_data(field = sensor)
    base_scope
      .where(field:)
      .sum(:value)
      .transform_keys { |year, month| { year: year.to_i, month: month.to_i } }
      .map { |key, value| { year: key[:year], month: key[:month], value: } }
  end

  def fetch_house_power_data
    excluded_sensors = SensorConfig.x.excluded_sensor_names

    return fetch_standard_data if excluded_sensors.empty?

    # Get house power data grouped by year/month
    house_power_by_month = base_scope.where(field: :house_power).sum(:value)

    # Get excluded sensors data grouped by year/month
    excluded_power_by_month =
      base_scope.where(field: excluded_sensors).sum(:value)

    # Combine the data
    house_power_by_month.map do |(year, month), house_value|
      excluded_value = excluded_power_by_month[[year, month]] || 0
      adjusted_value = house_value - excluded_value

      { year: year.to_i, month: month.to_i, value: adjusted_value }
    end
  end

  def fetch_inverter_power_data
    # If inverter_total_present, use only inverter_power and ignore individual sensors
    return fetch_standard_data if SensorConfig.x.inverter_total_present?

    # Otherwise, use sum of individual inverter sensors
    inverter_sensors = SensorConfig.x.existing_custom_inverter_sensor_names

    # If no individual sensors exist, fallback to total
    return fetch_standard_data if inverter_sensors.empty?

    # Sum individual inverter sensors
    fetch_inverter_parts_sum(inverter_sensors)
  end

  def fetch_inverter_parts_sum(inverter_sensors)
    # Single query for all inverter sensors, grouped by year/month
    base_scope
      .where(field: inverter_sensors)
      .sum(:value)
      .map do |(year, month), total_value|
        { year: year.to_i, month: month.to_i, value: total_value }
      end
  end

  def fetch_grid_power_data
    # Single query for both export and import, grouped by year/month/field
    base_scope
      .where(field: %i[grid_revenue grid_costs])
      .group(:field)
      .sum(:value)
      .group_by { |(year, month, _field), _value| [year.to_i, month.to_i] }
      .map do |(year, month), field_data|
        field_values =
          field_data.to_h { |(_, _, field), value| [field.to_sym, value] }
        {
          year: year,
          month: month,
          value: {
            grid_revenue: field_values[:grid_revenue] || 0,
            grid_costs: field_values[:grid_costs] || 0,
          },
        }
      end
  end

  def format_data(data)
    data.map do |(year, month), value|
      { year: year.to_i, month: month.to_i, value: }
    end
  end

  def base_scope
    SummaryValue
      .where(aggregation: :sum)
      .where(
        date:
          timeframe.effective_beginning_date..timeframe.effective_ending_date,
      )
      .group('EXTRACT(YEAR FROM date)', 'EXTRACT(MONTH FROM date)')
  end
end

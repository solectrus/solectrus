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

  def build_query_simple(start:, stop:, period:, limit:)
    scope =
      Summary.where(date: start..stop).where(
        Summary.arel_table[:"sum_#{sensor}"].gt(0),
      )

    sort_order = desc ? :desc : :asc
    sensor_column = :"#{calc}_#{sensor}"

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

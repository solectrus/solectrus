class ConsumptionChart < ChartBase
  def initialize
    super(sensors: SensorConfig.x.inverter_sensor_names + %i[grid_export_power])
  end

  def call(timeframe)
    return {} unless SensorConfig.x.exists_all?(*sensors)

    super

    case timeframe.id
    when :now
      chart_single start: 1.hour.ago + 1.second,
                   stop: 1.second.since,
                   window: WINDOW[timeframe.id]
    when :day
      chart_single start: timeframe.beginning,
                   stop: timeframe.ending,
                   window: WINDOW[timeframe.id]
    when :days, :week, :month, :months, :year, :years, :all
      query_sql(timeframe:)
    end
  end

  private

  def inverter_power_field(name = :inverter_power)
    SensorConfig.x.field(name)
  end

  def inverter_power_measurement(name = :inverter_power)
    SensorConfig.x.measurement(name)
  end

  def grid_export_power_field
    SensorConfig.x.field(:grid_export_power)
  end

  def grid_export_power_measurement
    SensorConfig.x.measurement(:grid_export_power)
  end

  def chart_single(start:, window:, stop: nil) # rubocop:disable Metrics/AbcSize
    q = []

    q << from_bucket

    # To ensure that we capture data even when measurements are sparse (e.g. every 15 minutes),
    # we extend the time period backwards by one hour. From the data received,
    # everything outside the desired range is then filtered out.
    q << "|> #{range(start: start - 1.hour, stop:)}"

    q << "|> #{filter}"
    q << '|> aggregateWindow(every: 5s, fn: last)'
    q << '|> fill(usePrevious: true)'
    q << "|> aggregateWindow(every: #{window}, fn: mean)"
    q << '|> pivot(rowKey:["_time"], columnKey: ["_measurement", "_field"], valueColumn: "_value")'

    if SensorConfig.x.multi_inverter? && !SensorConfig.x.inverter_total_present?
      inverter_sum_expr =
        SensorConfig
          .x
          .inverter_sensor_names
          .map do |m|
            "(if exists r[\"#{inverter_power_measurement(m)}_#{inverter_power_field(m)}\"] then r[\"#{inverter_power_measurement(m)}_#{inverter_power_field(m)}\"] else 0.0)"
          end
          .join(' + ')

      q << "|> map(fn: (r) => (
                 { r with inverter_power_sum: #{inverter_sum_expr} }
               ))"
      q << "|> map(fn: (r) => (
          { r with consumption:
              if r[\"#{grid_export_power_measurement}_#{grid_export_power_field}\"] > r.inverter_power_sum then
                0.0
              else
                (100.0 * (r.inverter_power_sum - r[\"#{grid_export_power_measurement}_#{grid_export_power_field}\"]) / r.inverter_power_sum)
          }
         ))"
    else
      q << "|> map(fn: (r) => (
                 { r with consumption:
                     if r[\"#{grid_export_power_measurement}_#{grid_export_power_field}\"] > r[\"#{inverter_power_measurement}_#{inverter_power_field}\"] then
                       0.0
                      else
                       (100.0 * (r[\"#{inverter_power_measurement}_#{inverter_power_field}\"] - r[\"#{grid_export_power_measurement}_#{grid_export_power_field}\"]) / r[\"#{grid_export_power_measurement}_#{grid_export_power_field}\"])
                 }
               ))"
    end

    q << '|> keep(columns: ["_time", "consumption"])'

    raw = query(q.join)
    to_array(raw, start:)
  end

  def query_sql(timeframe:)
    result =
      SummaryValue
        .where(
          date: timeframe.beginning..timeframe.ending,
          field: sensors,
          aggregation: 'sum',
        )
        .group_by_period(grouping_period(timeframe), :date)
        .group(:field)
        .sum(:value)

    dates(timeframe).map do |date|
      inverter_power =
        if SensorConfig.x.multi_inverter?
          [
            result[[date, 'inverter_power_1']],
            result[[date, 'inverter_power_2']],
            result[[date, 'inverter_power_3']],
            result[[date, 'inverter_power_4']],
            result[[date, 'inverter_power_5']],
          ].compact.presence&.sum || result[[date, 'inverter_power']]
        else
          result[[date, 'inverter_power']]
        end

      grid_export_power = result[[date, 'grid_export_power']]

      consumption =
        if inverter_power
          [inverter_power - (grid_export_power || 0), 0].max.fdiv(
            inverter_power,
          ) * 100
        end

      [date.to_time, consumption]
    end
  end

  def to_array(raw, start:)
    value_to_array(raw.first, start:)
  end

  def value_to_array(raw, start:)
    return [] unless raw&.records

    raw
      .records
      .each_cons(2) # InfluxDB returns data one-off
      .filter_map do |record, next_record|
        time = Time.zone.parse(record.values['_time'])

        # Take only data that ist after the desired start
        # (needed because the start was extended by one hour)
        next if time < start

        value =
          (next_record.values['consumption']&.clamp(0, 100) unless time.future?)

        [time, value]
      end
  end
end

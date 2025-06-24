class Insights # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, timeframe:)
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :sensor, :timeframe

  def value
    return unless calculator.respond_to?(sensor)

    @value ||= calculator.public_send(sensor).to_f
  end

  def costs
    if %i[
         wallbox_power
         heatpump_power
         house_power
         house_power_without_custom
         battery_power
       ].exclude?(sensor) && !sensor.start_with?('custom_')
      return
    end
    return unless ApplicationPolicy.power_splitter?

    costs_field =
      if sensor == :battery_power
        'battery_charging_costs'
      else
        "#{sensor}_costs".sub('_power', '')
        # Example: custom_01_costs,  house_without_custom_costs, wallbox_costs, ...
      end

    calculator.public_send(costs_field)
  end

  def sensors_with_grid_ratio
    %i[
      wallbox_power
      heatpump_power
      house_power
      battery_power
      house_power_without_custom
    ] + SensorConfig.x.existing_custom_sensor_names
  end

  def power_grid_ratio
    return unless sensor.in?(sensors_with_grid_ratio)

    if sensor == :battery_power
      calculator.battery_charging_power_grid_ratio
    else
      calculator.public_send(:"#{sensor}_grid_ratio")
    end
  end

  def costs_grid
    return if %i[wallbox_power heatpump_power house_power].exclude?(sensor)

    costs_field = "#{sensor}_costs_grid".sub('_power', '')
    calculator.public_send(costs_field)
  end

  def costs_pv
    return if %i[wallbox_power heatpump_power house_power].exclude?(sensor)

    costs_field = "#{sensor}_costs_pv".sub('_power', '')
    calculator.public_send(costs_field)
  end

  def multi_inverter?
    sensor == :inverter_power && SensorConfig.x.multi_inverter? &&
      ApplicationPolicy.multi_inverter?
  end

  def inverter_sensor_values
    return unless multi_inverter?

    @inverter_sensor_values ||= build_inverter_sensor_data
  end

  def per_day_value
    return if timeframe.day?

    calculator.per_day(value)
  end

  def inverter_power_per_kwp
    return unless sensor == :inverter_power

    calculator.inverter_power_per_kwp
  end

  def feed_in_revenue
    return unless sensor == :grid_power

    calculator.got
  end

  def grid_costs
    return unless sensor == :grid_power

    calculator.paid.abs
  end

  delegate :solar_price, to: :calculator

  def battery_charging_power
    return unless sensor == :battery_power

    calculator.battery_charging_power
  end

  def battery_discharging_power
    return unless sensor == :battery_power

    calculator.battery_discharging_power
  end

  def monthly_trend
    @monthly_trend ||=
      if timeframe.month_like? && Trend.available_for?(sensor:, timeframe:)
        Trend.new(
          sensor:,
          timeframe:,
          current_value: value,
          base: :previous_period,
        )
      end
  end

  def yearly_trend
    @yearly_trend ||=
      if Trend.available_for?(sensor:, timeframe:)
        Trend.new(
          sensor:,
          timeframe:,
          current_value: value,
          base: :previous_year,
        )
      end
  end

  def maximum(sensor, key = :value)
    @maximum ||= {}
    @maximum[sensor] ||= extremum(sensor, :max)
    return unless @maximum[sensor]

    @maximum[sensor][key]
  end

  def minimum(sensor, key = :value)
    @minimum ||= {}
    @minimum[sensor] ||= extremum(sensor, :min)
    return unless @minimum[sensor]

    @minimum[sensor][key]
  end

  def battery_empty_days
    SummaryValue
      .where(field: :battery_soc, aggregation: :min)
      .where(value: 0)
      .where(
        date:
          timeframe.effective_beginning_date..timeframe.effective_ending_date,
      )
      .select(:date)
      .distinct
      .count
  end

  def battery_full_days
    SummaryValue
      .where(field: :battery_soc, aggregation: :max)
      .where(value: 100)
      .where(
        date:
          timeframe.effective_beginning_date..timeframe.effective_ending_date,
      )
      .select(:date)
      .distinct
      .count
  end

  def battery_soc_longest_streak # rubocop:disable Metrics/MethodLength
    @battery_soc_longest_streak ||=
      begin
        sql = <<~SQL.squish
          WITH good_days AS (
            SELECT DISTINCT date
            FROM summary_values
            WHERE field = 'battery_soc'
              AND aggregation = 'min'
              AND value > 0
              AND date >= $1
              AND date <= $2
          ),
          seq AS (
            SELECT
              date,
              date - (ROW_NUMBER() OVER (ORDER BY date))::int AS grp
            FROM good_days
          ),
          streaks AS (
            SELECT
              MIN(date) AS start_date,
              MAX(date) AS end_date,
              COUNT(*) AS streak_len
            FROM seq
            GROUP BY grp
          )
          SELECT
            start_date,
            end_date,
            streak_len
          FROM streaks
          ORDER BY streak_len DESC
          LIMIT 1
        SQL

        result =
          ActiveRecord::Base.connection.exec_query(
            sql,
            'battery_soc_longest_streak',
            [
              timeframe.effective_beginning_date,
              timeframe.effective_ending_date,
            ],
          )

        row = result.first

        if row
          {
            from: row['start_date'],
            to: row['end_date'],
            length: row['streak_len'],
          }
        else
          { from: nil, to: nil, length: 0 }
        end
      end
  end

  private

  def extremum(sensor, aggregation)
    return if timeframe.day?
    return unless sensor.in?(SensorConfig::TOP10_SENSORS)

    top =
      PowerRanking.new(
        sensor:,
        desc: aggregation == :max,
        calc: 'sum',
        from: timeframe.effective_beginning_date,
        to: timeframe.effective_ending_date,
        limit: 1,
      )

    top.days.first
  end

  def calculator
    @calculator ||=
      Calculator::Range.new(timeframe, calculations: required_calculations)
  end

  def required_calculations
    [
      *SensorConfig.x.inverter_sensor_names.map do |sensor_name|
        Queries::Calculation.new(sensor_name, :sum, :sum)
      end,
      Queries::Calculation.new(:house_power, :sum, :sum),
      Queries::Calculation.new(:heatpump_power, :sum, :sum),
      Queries::Calculation.new(:wallbox_power, :sum, :sum),
      Queries::Calculation.new(:battery_charging_power, :sum, :sum),
      Queries::Calculation.new(:battery_discharging_power, :sum, :sum),
      Queries::Calculation.new(:grid_import_power, :sum, :sum),
      Queries::Calculation.new(:grid_export_power, :sum, :sum),
      Queries::Calculation.new(:heatpump_power_grid, :sum, :sum),
      Queries::Calculation.new(:wallbox_power_grid, :sum, :sum),
      Queries::Calculation.new(:house_power_grid, :sum, :sum),
      Queries::Calculation.new(:battery_charging_power_grid, :sum, :sum),
      *SensorConfig.x.excluded_sensor_names.flat_map do |sensor_name|
        [
          Queries::Calculation.new(sensor_name, :sum, :sum),
          Queries::Calculation.new(:"#{sensor_name}_grid", :sum, :sum),
        ]
      end,
    ]
  end

  def build_inverter_sensor_data
    active_sensors =
      (
        SensorConfig.x.inverter_sensor_names - [:inverter_power]
      ).select { |sensor_name| calculator.public_send(sensor_name)&.positive? }

    total_value =
      active_sensors.sum do |sensor_name|
        calculator.public_send(sensor_name) || 0
      end

    active_sensors.map do |sensor_name|
      sensor_value = calculator.public_send(sensor_name)

      {
        name: sensor_name,
        value: sensor_value,
        percentage: percentage(sensor_value, total_value),
      }
    end
  end

  def percentage(value, total)
    return 0 unless total.positive?

    (value * 100.0 / total).round
  end
end

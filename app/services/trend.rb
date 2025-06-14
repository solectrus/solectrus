class Trend
  def self.available_for?(sensor:, timeframe:)
    return false unless timeframe.year_like? || timeframe.month_like?
    return false unless SummaryValue.fields.key?(sensor)
    return false unless sensor.in?(TRENDABLE_SENSORS)

    true
  end

  TRENDABLE_SENSORS = %i[
    inverter_power
    inverter_power_1
    inverter_power_2
    inverter_power_3
    inverter_power_4
    inverter_power_5
    grid_import_power
    grid_export_power
    battery_charging_power
    battery_discharging_power
    heatpump_power
    wallbox_power
    house_power
  ].freeze
  private_constant :TRENDABLE_SENSORS

  def initialize(sensor:, timeframe:, current_value:, base: nil)
    base ||=
      if timeframe.year_like?
        :previous_year
      elsif timeframe.month_like?
        :month_from_previous_year
      end

    unless base.in?(%i[previous_year month_from_previous_year previous_month])
      raise ArgumentError, "Invalid base: #{base}"
    end
    if timeframe.year? && base != :previous_year
      raise ArgumentError, 'Base must be :previous_year for yearly timeframe'
    end

    @sensor = sensor
    @timeframe = timeframe
    @base = base
    @current_value = current_value
  end

  attr_reader :sensor, :timeframe, :base, :current_value

  def valid?
    if first_date.nil? || base_timeframe.effective_beginning_date < first_date
      return false
    end

    true
  end

  def first_date
    @first_date ||= SummaryValue.where(field: relevant_sensors).minimum(:date)
  end

  def base_timeframe
    @base_timeframe ||=
      case base
      when :previous_year
        previous_year
      when :month_from_previous_year
        month_from_previous_year
      when :previous_month
        previous_month
      end
  end

  def previous_year
    if timeframe.current?
      first_day = timeframe.effective_beginning_date - 1.year
      last_day = timeframe.effective_ending_date - 1.year

      Timeframe.new "#{first_day}..#{last_day}"
    else
      year = timeframe.date.year - 1
      Timeframe.new year.to_s
    end
  end

  def previous_month
    if timeframe.current?
      first_day = 1.month.ago.beginning_of_month.to_date
      last_day = 1.month.ago.end_of_month.to_date.change(day: Date.current.day)

      Timeframe.new "#{first_day}..#{last_day}"
    else
      day = timeframe.date - 1.month

      Timeframe.new "#{day.year}-#{format('%02d', day.month)}"
    end
  end

  def month_from_previous_year
    if timeframe.current?
      first_day = Date.current.beginning_of_month - 1.year
      last_day = Date.current - 1.year

      Timeframe.new "#{first_day}..#{last_day}"
    else
      day = timeframe.date - 1.year

      Timeframe.new "#{day.year}-#{format('%02d', day.month)}"
    end
  end

  def base_value
    return unless valid?
    return unless base_calculator.respond_to?(sensor)

    @base_value ||= base_calculator.public_send(sensor)
  end

  def factor
    return unless base_value&.nonzero?

    current_value.fdiv(base_value)
  end

  def percent
    return unless factor

    (factor - 1) * 100
  end

  def same?
    percent&.round&.zero?
  end

  def more_is_better?
    sensor.in?(
      %i[
        inverter_power
        inverter_power_1
        inverter_power_2
        inverter_power_3
        inverter_power_4
        inverter_power_5
        grid_export_power
        battery_charging_power
        battery_discharging_power
      ],
    )
  end

  def diff
    return unless base_value && current_value

    current_value - base_value
  end

  private

  def base_calculator
    @base_calculator ||= Calculator::Range.new(base_timeframe)
  end

  def relevant_sensors
    if sensor == :inverter_power
      SensorConfig.x.inverter_sensor_names
    else
      [sensor]
    end
  end
end

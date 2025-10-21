class Trend
  def self.available_for?(sensor:, timeframe:)
    return false unless timeframe.year_like? || timeframe.month_like?

    return false unless sensor.trendable?

    true
  end

  def initialize(sensor:, timeframe:, current_value:, base:)
    unless base.in?(%i[previous_year previous_period])
      raise ArgumentError, "Invalid base: #{base}"
    end

    @sensor = sensor
    @timeframe = timeframe
    @base = base
    @current_value = current_value
  end

  attr_reader :sensor, :timeframe, :base, :current_value

  def valid?
    # Don't show trends for single-day ranges - check this first to avoid
    # creating invalid base_timeframe ranges
    return false if timeframe.days_passed <= 1

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
      when :previous_period
        if timeframe.year_like?
          previous_year
        elsif timeframe.month_like?
          previous_month
        else
          raise ArgumentError, "timeframe unknown: #{timeframe}"
        end
      end
  end

  def previous_year
    if timeframe.year_like?
      if timeframe.current?
        first_day = timeframe.effective_beginning_date - 1.year
        last_day = timeframe.effective_ending_date - 1.year

        Timeframe.new "#{first_day}..#{last_day}"
      else
        year = timeframe.date.year - 1
        Timeframe.new year.to_s
      end
    elsif timeframe.month_like?
      month_from_previous_year
    end
  end

  def previous_month
    if timeframe.current?
      first_day = timeframe.effective_beginning_date - 1.month
      last_day = timeframe.effective_ending_date - 1.month

      Timeframe.new "#{first_day}..#{last_day}"
    else
      day = timeframe.date - 1.month

      Timeframe.new "#{day.year}-#{format('%02d', day.month)}"
    end
  end

  def month_from_previous_year
    if timeframe.current?
      first_day = timeframe.effective_beginning_date - 1.year
      last_day = timeframe.effective_ending_date - 1.year

      Timeframe.new "#{first_day}..#{last_day}"
    else
      day = timeframe.date - 1.year

      Timeframe.new "#{day.year}-#{format('%02d', day.month)}"
    end
  end

  def base_value
    return unless valid?
    return unless base_data.respond_to?(sensor.name)

    @base_value ||= base_data.public_send(sensor.name)
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

  delegate :more_is_better?, to: :sensor

  def diff
    return unless base_value && current_value

    current_value - base_value
  end

  private

  def base_data
    @base_data ||=
      Sensor::Query::Sql
        .new do |q|
          q.public_send(sensor.trend_aggregation, sensor.name)
          q.timeframe base_timeframe
        end
        .call
  end

  def relevant_sensors
    # Use DependencyResolver to get all dependencies, then filter to storable ones
    Sensor::DependencyResolver
      .new(sensor.name, context: :sql)
      .resolve
      .select { |s| Sensor::Registry[s].store_in_summary? }
  end
end

class HeatmapTile::Component < ViewComponent::Base
  def initialize(data:, sensor:, timeframe:)
    super()
    @data = data
    @sensor = sensor
    @timeframe = timeframe
  end

  attr_reader :data, :sensor, :timeframe

  private

  def years
    timeframe.year? ? [] : data.keys.sort
  end

  def months
    timeframe.year? ? data.keys.sort : []
  end

  def value_for(year, month)
    return unless timeframe.all?

    data.dig(year, month)
  end

  def daily_value_for(month, day)
    return unless timeframe.year?

    data.dig(month, day)
  end

  def current_year
    timeframe.year? ? timeframe.date.year : Date.current.year
  end

  def max_value
    @max_value ||=
      begin
        all_values = data.values.flat_map(&:values).compact

        if grid_power?
          # For grid_power, find max absolute difference between revenue and costs
          all_values.map { |value| grid_eur_diff(value).abs }.max || 0
        else
          all_values.max || 0
        end
      end
  end

  def grid_power?
    sensor == :grid_power
  end

  def grid_fields
    %i[grid_revenue grid_costs]
  end

  def grid_eur_diff(value)
    return 0 unless value.is_a?(Hash)

    (value[:grid_revenue] || 0) - (value[:grid_costs] || 0)
  end

  def background_class(value)
    if value.nil? || (value.respond_to?(:zero?) && value.zero?)
      return 'bg-inherit'
    end
    return 'bg-inherit' if grid_power? && grid_eur_diff(value).zero?

    grid_power? ? grid_eur_color(value) : sensor_background_color
  end

  def opacity(value)
    return if value.nil? || (value.respond_to?(:zero?) && value.zero?)
    return if grid_power? && grid_eur_diff(value).zero?

    (grid_power? ? grid_eur_opacity(value) : standard_opacity(value)).round(2)
  end

  def grid_eur_color(value)
    balance = grid_eur_diff(value)

    if balance.positive?
      sensor_background_color(:grid_export_power)
    else
      sensor_background_color(:grid_import_power)
    end
  end

  def grid_eur_opacity(value)
    balance = grid_eur_diff(value)
    return 0.5 if max_value.zero?

    balance.abs.fdiv(max_value).clamp(0, 1)
  end

  def standard_opacity(value)
    return 0.5 if max_value.zero?

    value.fdiv(max_value).clamp(0, 1)
  end

  def sensor_background_color(chosen_sensor = sensor)
    case chosen_sensor
    when :inverter_power, :grid_export_power
      'bg-green-600 dark:bg-green-400'
    when :grid_import_power
      'bg-red-600 dark:bg-red-400'
    when :house_power
      'bg-slate-500 dark:bg-slate-600'
    when :heatpump_power
      'bg-slate-600 dark:bg-slate-600'
    when :wallbox_power
      'bg-slate-700 dark:bg-slate-600'
    when :battery_power
      'bg-green-700 dark:bg-green-900'
    else
      'bg-gray-500 dark:bg-gray-400'
    end
  end
end

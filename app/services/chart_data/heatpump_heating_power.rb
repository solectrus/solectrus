class ChartData::HeatpumpHeatingPower < ChartData::Base
  private

  def data
    case timeframe.id
    when :now
      {
        labels: labels_for(:heatpump_power_env),
        datasets: [
          dataset(:heatpump_power).merge(fill: 'origin'),
          dataset(:heatpump_power_env).merge(fill: '-1'),
        ],
      }
    when :day
      {
        labels: labels_for(:heatpump_power_env),
        datasets: [
          dataset(:heatpump_power_grid).merge(fill: 'origin'),
          dataset(:heatpump_power_pv).merge(fill: '-1'),
          dataset(:heatpump_power_env).merge(fill: '-1'),
        ],
      }
    else
      {
        labels: labels_for(:heatpump_heating_power),
        datasets: [
          dataset(:heatpump_power_grid),
          dataset(:heatpump_power_pv),
          dataset(:heatpump_power_env),
        ],
      }
    end
  end

  def labels_for(name)
    chart[name]&.map { |x| x.first.to_i * 1000 }
  end

  def dataset(name)
    { data: chart[name]&.map(&:second) }.merge(style(name))
  end

  def chart
    @chart ||=
      begin
        raw = PowerChart.new(sensors:).call(timeframe, interpolate: true)
        series = build_series(raw)

        case timeframe.id
        when :now
          # No Power-Splitter available for NOW, so we use total power
          { heatpump_power_env: series[:env], heatpump_power: series[:total] }
        when :day
          {
            heatpump_power_env: series[:env],
            heatpump_power_pv: series[:pv],
            heatpump_power_grid: series[:grid],
          }
        else
          {
            heatpump_heating_power: series[:heating],
            heatpump_power_env: series[:env],
            heatpump_power_pv: series[:pv],
            heatpump_power_grid: series[:grid],
          }
        end
      end
  end

  # Single pass to build arrays for grid, pv, env, and heating
  def build_series(raw) # rubocop:disable Metrics/AbcSize
    heating_data = raw[:heatpump_heating_power] || []
    power_data = raw[:heatpump_power] || []
    grid_data = raw[:heatpump_power_grid] || []

    # Pre-allocate arrays for better performance
    size = heating_data.size
    list_heating = Array.new(size)
    list_power_grid = Array.new(size)
    list_power_pv = Array.new(size)
    list_power_total = Array.new(size)
    list_env = Array.new(size)

    heating_data.each_with_index do |(timestamp, heating), index|
      if heating&.positive?
        # Total power consumption of the heat pump
        power = power_data.dig(index, 1)

        # Power consumption from the grid (capped to heating output)
        power_from_grid = grid_data.dig(index, 1).to_f.clamp(0, heating)

        # Power consumption from PV (capped to remaining heating capacity)
        power_from_pv =
          (power - power_from_grid).clamp(0, heating - power_from_grid)

        # Heat from environment is difference between heating output and electrical power
        heat_from_env = [heating - power_from_grid - power_from_pv, 0].max

        power_total = power_from_grid + power_from_pv
      else
        heating = 0
        power_total = 0
        power_from_grid = 0
        power_from_pv = 0
        heat_from_env = 0
      end

      list_heating[index] = [timestamp, heating]
      list_power_grid[index] = [timestamp, power_from_grid]
      list_power_pv[index] = [timestamp, power_from_pv]
      list_power_total[index] = [timestamp, power_total]
      list_env[index] = [timestamp, heat_from_env]
    end

    {
      heating: list_heating,
      grid: list_power_grid,
      pv: list_power_pv,
      total: list_power_total,
      env: list_env,
    }
  end

  def sensors
    if timeframe.now?
      %i[heatpump_heating_power heatpump_power]
    else
      %i[heatpump_heating_power heatpump_power heatpump_power_grid]
    end
  end

  def style(name)
    if timeframe.short?
      {
        # Base color, will be changed to gradient in JS
        backgroundColor: BACKGROUND_COLORS[name],
        barPercentage: 0.7,
        categoryPercentage: 0.7,
        borderWidth: 1,
        borderRadius: 5,
        borderSkipped: 'start',
        label: SensorConfig.x.display_name(name),
        stack: 'HeatingPower',
      }
    else
      {
        fill: 'origin',
        # Base color, will be changed to gradient in JS
        backgroundColor: BACKGROUND_COLORS[name],
        borderWidth: 1,
        borderRadius: 5,
        borderColor: BACKGROUND_COLORS[name],
        stack: name == :heatpump_heating_power ? nil : 'HeatingPower',
        label: SensorConfig.x.display_name(name),
      }
    end
  end

  BACKGROUND_COLORS = {
    heatpump_power_env: '#0ea5e9', # sky-500
    heatpump_power_pv: '#16a34a', # bg-green-600
    heatpump_power_grid: '#dc2626', # bg-red-600
    heatpump_power: '#475569', # bg-slate-600
  }.freeze
  private_constant :BACKGROUND_COLORS
end

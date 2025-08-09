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
    { data: chart[name]&.map { |x| x.second.to_f } }.merge(style(name))
  end

  def chart
    @chart ||=
      begin
        raw = PowerChart.new(sensors:).call(timeframe, interpolate: true)
        series = build_series(raw)

        case timeframe.id
        when :now
          {
            heatpump_power_env: series[:env],
            heatpump_power: raw[:heatpump_power],
          }
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
  def build_series(raw)
    grid = []
    pv = []
    env = []
    heating = []

    raw[:heatpump_heating_power]&.each_with_index do |x, index|
      label = x.first
      heating_val = x.second.to_f
      total_power = raw.dig(:heatpump_power, index, 1).to_f
      grid_raw = raw.dig(:heatpump_power_grid, index, 1).to_f

      grid_capped = grid_raw.clamp(0, heating_val)
      pv_raw = total_power - grid_raw
      pv_capped = pv_raw.clamp(0, heating_val - grid_capped)
      env_val = [heating_val - (grid_capped + pv_capped), 0].max

      grid << [label, grid_capped]
      pv << [label, pv_capped]
      env << [label, env_val]
      heating << [label, heating_val]
    end

    { grid:, pv:, env:, heating: }
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

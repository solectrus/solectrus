class ChartData::HeatpumpHeatingPower < ChartData::Base # rubocop:disable Metrics/ClassLength
  private

  def data
    case timeframe.id
    when :now
      {
        labels: labels_for(:environment),
        datasets: [
          dataset(:power).merge(fill: 'origin'),
          dataset(:environment).merge(fill: '-1'),
        ],
      }
    when :day
      {
        labels: labels_for(:environment),
        datasets: [
          dataset(:grid).merge(fill: 'origin'),
          dataset(:pv).merge(fill: '-1'),
          dataset(:environment).merge(fill: '-1'),
        ],
      }
    else
      {
        labels: labels_for(:heating),
        datasets: [
          dataset(:heating),
          dataset(:grid),
          dataset(:pv),
          dataset(:environment),
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
      case timeframe.id
      when :now
        chart_now
      when :day
        chart_day
      else
        chart_splitted
      end
  end

  def chart_now
    raw = PowerChart.new(sensors:).call(timeframe, interpolate: true)

    {
      environment:
        raw[:heatpump_heating_power]&.each_with_index&.map do |x, index|
          label = x.first
          heating_power = x.second
          heatpump_power = raw[:heatpump_power][index].second

          value =
            if heating_power && heatpump_power &&
                 heating_power >= heatpump_power
              heating_power - heatpump_power
            end

          [label, value]
        end,
      power: raw[:heatpump_power],
    }
  end

  def chart_day # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raw = PowerChart.new(sensors:).call(timeframe, interpolate: true)

    {
      environment:
        raw[:heatpump_heating_power]&.each_with_index&.map do |x, index|
          label = x.first
          heating_power = x.second
          heatpump_power = raw[:heatpump_power][index].second

          value =
            if heating_power && heatpump_power &&
                 heating_power >= heatpump_power
              heating_power - heatpump_power
            end

          [label, value]
        end,
      pv:
        raw[:heatpump_power]&.each_with_index&.map do |x, index|
          label = x.first
          value = x.second.to_f - raw[:heatpump_power_grid][index].second.to_f
          value =
            value.clamp(0, raw[:heatpump_heating_power][index].second.to_f)

          [label, value]
        end,
      grid:
        raw[:heatpump_power_grid]&.each_with_index&.map do |x, index|
          label = x.first
          value =
            x.second&.clamp(0, raw[:heatpump_heating_power][index].second.to_f)

          [label, value]
        end,
    }
  end

  def chart_splitted # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    raw = PowerChart.new(sensors:).call(timeframe, interpolate: true)

    {
      heating:
        raw[:heatpump_heating_power]&.map do |x|
          label = x.first
          value = x.second.to_f

          [label, value]
        end,
      environment:
        raw[:heatpump_heating_power]&.each_with_index&.map do |x, index|
          label = x.first
          value = x.second.to_f - raw[:heatpump_power][index].second.to_f
          value = [value, 0].max # Ensure environment power is not negative

          [label, value]
        end,
      pv:
        raw[:heatpump_power]&.each_with_index&.map do |x, index|
          label = x.first
          value = x.second.to_f - raw[:heatpump_power_grid][index].second.to_f
          value =
            value.clamp(0, raw[:heatpump_heating_power][index].second.to_f)

          [label, value]
        end,
      grid:
        raw[:heatpump_power_grid]&.each_with_index&.map do |x, index|
          label = x.first
          value =
            x.second&.clamp(0, raw[:heatpump_heating_power][index].second.to_f)

          [label, value]
        end,
    }
  end

  def sensors
    if timeframe.now?
      %i[heatpump_heating_power heatpump_power]
    else
      %i[heatpump_heating_power heatpump_power heatpump_power_grid]
    end
  end

  def style(name) # rubocop:disable Metrics/CyclomaticComplexity
    if timeframe.short?
      {
        # Base color, will be changed to gradient in JS
        backgroundColor: BACKGROUND_COLORS[name],
        borderWidth: 1,
        borderRadius: 5,
        borderSkipped: 'start',
        label: LABELS[name],
        stack: 'Split',
      }
    else
      {
        fill: 'origin',
        # Base color, will be changed to gradient in JS
        backgroundColor: BACKGROUND_COLORS[name],
        barPercentage: name == :heating ? 0.4 : 1.6,
        categoryPercentage: 0.7,
        borderRadius:
          case name
          when :heating
            { topLeft: 5 }
          when :environment
            { topRight: 5 }
          end,
        borderWidth:
          case name
          when :heating
            { top: 1, left: 1, right: 1 }
          when :environment, :grid, :pv
            { top: 1, right: 1 }
          end,
        borderColor: BACKGROUND_COLORS[name],
        stack: name == :heating ? nil : 'Split',
        label: LABELS[name],
      }
    end
  end

  BACKGROUND_COLORS = {
    heatpump_heating_power: '#c2410c', # orange-700
    heating: '#44403c', # stone-700
    environment: '#0ea5e9', # sky-500
    pv: '#16a34a', # bg-green-600
    grid: '#dc2626', # bg-red-600
    power: '#475569', # bg-slate-600
  }.freeze
  private_constant :BACKGROUND_COLORS

  LABELS = {
    heatpump_heating_power: 'Erzeugte Wärme',
    heating: 'Erzeugte Wärme',
    environment: 'Aus der Umgebung',
    pv: 'Aus Photovoltaik',
    grid: 'Aus dem Netz',
    power: 'Aus Strom',
  }.freeze
  private_constant :LABELS
end

class ChartData::HeatpumpCop < ChartData::Base
  def suggested_max
    data[:datasets].first[:data].compact.max
  end

  def type
    if timeframe.short? || (timeframe.days_passed > 300 && timeframe.days?)
      'line'
    else
      'bar'
    end
  end

  private

  def data
    {
      labels: combined_chart.map { |time, _| time.to_i * 1000 },
      datasets: [
        {
          label: I18n.t('calculator.heatpump_cop'),
          data: combined_chart.map { |_, cop| cop },
        }.merge(style),
      ],
    }
  end

  def background_colors_with_opacity
    power_values = chart_heatpump_power.filter_map(&:second)
    return [] if power_values.empty?

    max_power = all_time_max_power
    min_power = all_time_min_power
    power_range = max_power - min_power

    return [] if power_range.zero?

    chart_heatpump_power.map do |_, power|
      if power.nil? || power.zero?
        'rgba(3, 105, 161, 0.3)'
      else
        normalized = (power - min_power) / power_range
        opacity = (normalized * 0.7) + 0.3
        "rgba(3, 105, 161, #{opacity.round(2)})"
      end
    end
  end

  def combined_chart
    @combined_chart ||=
      chart_heatpump_power.map.with_index do |(time, power), index|
        heating = chart_heatpump_heating_power[index]&.second
        cop = heating&.fdiv(power) if power&.nonzero?

        [time, cop]
      end
  end

  def chart_heatpump_power
    @chart_heatpump_power ||= chart[:heatpump_power] || []
  end

  def chart_heatpump_heating_power
    @chart_heatpump_heating_power ||= chart[:heatpump_heating_power] || []
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: %i[heatpump_power heatpump_heating_power]).call(
        timeframe,
      )
  end

  def all_time_max_power
    @all_time_max_power ||=
      Rails
        .cache
        .fetch("heatpump_power_max_#{ranking_period}", expires_in: 1.day) do
          power_ranking(desc: true).first&.dig(:value) || 0
        end
  end

  def all_time_min_power
    @all_time_min_power ||=
      Rails
        .cache
        .fetch("heatpump_power_min_#{ranking_period}", expires_in: 1.day) do
          power_ranking(desc: false).first&.dig(:value) || 0
        end
  end

  def power_ranking(desc:)
    PowerRanking.new(
      sensor: :heatpump_power,
      calc: 'sum',
      desc:,
      limit: 1,
    ).public_send(ranking_period)
  end

  def ranking_period
    @ranking_period ||=
      case timeframe.id
      when :all, :years
        :years # Multi-year view: bars are years
      when :year, :months
        :months # Year view: bars are months
      else
        :days # Month/day/week/range view: bars are days
      end
  end

  def main_color
    '#0369a1' # bg-sky-700
  end

  def style
    super.merge(
      backgroundColor:
        case type
        when 'bar'
          background_colors_with_opacity
        when 'line'
          main_color
        end,
      borderColor: main_color,
    )
  end
end

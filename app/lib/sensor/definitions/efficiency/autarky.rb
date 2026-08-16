class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  value unit: :percent, range: (0..100)

  color do |percent|
    if percent.nil?
      # No value context (legend, Top 10 bar): flat identity color.
      background = 'bg-sensor-autarky'
      text = 'text-white dark:text-slate-400'
    else
      # With a value (radial badge, stats): neutral background, value colored by
      # quality (red / orange / green).
      background = 'xl:tall:bg-slate-200 xl:tall:dark:bg-slate-800'
      text =
        if percent >= 67
          'text-signal-positive'
        elsif percent >= 34
          'text-signal-warning'
        else
          'text-signal-negative'
        end
    end

    { background:, text:, border: '' }
  end

  depends_on :grid_import_power, :total_consumption

  calculate do |grid_import_power:, total_consumption:, **|
    return unless total_consumption
    return if total_consumption.zero?
    return unless grid_import_power

    # 100.0, and no rounding: how many decimals a share deserves is the
    # presentation layer's call (percent prints none, MCP keeps a tenth), and
    # rounding here would make this block disagree with #sql_calculation, which
    # computes the same share and cannot round.
    (total_consumption - grid_import_power) * 100.0 / total_consumption
  end

  trend more_is_better: true, aggregation: :avg

  # Averaged ratio: a partial period is misleading, and the ranking keeps
  # incomplete periods out for every :avg aggregation.
  aggregations stored: false, computed: [:avg], meta: [:avg], top10: true

  home_pages :balance

  chart { |timeframe| Sensor::Chart::Autarky.new(timeframe:) }

  def sql_calculation = autarky_sql(period: false)

  # For period aggregations (week/month/year) sum the daily components first,
  # then compute the ratio, instead of averaging daily autarky values.
  def sql_calculation_period = autarky_sql(period: true)

  private

  # Autarky = share of consumption covered without the grid, floored at 0.
  # NULLIF guards periods without any consumption.
  def autarky_sql(period:)
    total = total_consumption_sql(period:)
    grid = sql_sum('COALESCE(grid_import_power_sum, 0)', period:)
    "GREATEST((#{total} - #{grid}) * 100.0 / NULLIF(#{total}, 0), 0)"
  end

  # total_consumption is house_power plus the consumers excluded from it (heat
  # pump, wallbox, opt-out custom sensors). Sum the summary fields it resolves to.
  def total_consumption_sql(period:)
    terms =
      Sensor::Registry[:total_consumption].storable_fields.map do |field|
        sql_sum("COALESCE(#{field}_sum, 0)", period:)
      end
    "(#{terms.join(' + ')})"
  end
end

class Sensor::Chart::CaseTemp < Sensor::Chart::MinmaxBase
  # Minimum Y-axis span in degrees Celsius. The axis adapts to the actual
  # values, but never zooms in tighter than this, so near-constant
  # temperatures (e.g. on the live/day view) don't get magnified into
  # dramatic-looking swings while wider ranges still scale dynamically
  # (see issue #5694).
  MIN_SPAN = 10

  # Rough number of ticks to aim for when picking a "nice" axis step.
  TARGET_TICKS = 7

  # Allowed step sizes (times a power of ten); anything above falls back to 10.
  NICE_STEPS = [1, 2, 5].freeze

  private_constant :MIN_SPAN, :TARGET_TICKS, :NICE_STEPS

  def chart_sensor_names
    %i[case_temp]
  end

  def suggested_min
    dynamic_bounds&.dig(:min)
  end

  def suggested_max
    dynamic_bounds&.dig(:max)
  end

  # Both chart types share the same dynamic scaling. The historical bar views
  # need a hard min/max, though: Chart.js folds each bar's zero baseline into
  # the axis range, so a soft suggestedMin could never lift the floor off zero.
  # The live/day line view keeps soft bounds, so its axis can still grow with
  # incoming readings.
  def y_scale_options
    bounds = dynamic_bounds
    return super unless bounds

    base = super
    # Pin the step and tick count so every grid line of the rounded range shows
    ticks = {
      **base[:ticks],
      stepSize: bounds[:step],
      maxTicksLimit: tick_count(bounds),
    }
    scale = base.except(:suggestedMin, :suggestedMax).merge(ticks:)

    if type == 'bar'
      scale.merge(min: bounds[:min], max: bounds[:max])
    else
      scale.merge(suggestedMin: bounds[:min], suggestedMax: bounds[:max])
    end
  end

  private

  def tick_count(bounds)
    ((bounds[:max] - bounds[:min]) / bounds[:step]).round + 1
  end

  # Returns { min:, max:, step: } fitting the data, widened symmetrically to at
  # least MIN_SPAN and rounded outward to the next nice grid line. This keeps
  # clean axis labels (e.g. 24..38 instead of 24.6..37.8) with a little air
  # above and below the data, for both line and bar views. Returns nil when
  # there is no data, so Chart.js falls back to its own auto-scaling.
  def dynamic_bounds
    return @dynamic_bounds if defined?(@dynamic_bounds)

    @dynamic_bounds = compute_dynamic_bounds
  end

  def compute_dynamic_bounds
    values = chart_values
    return if values.blank?

    low, high = values.minmax
    missing = MIN_SPAN - (high - low)
    if missing.positive?
      low -= missing / 2.0
      high += missing / 2.0
    end

    step = nice_step((high - low) / TARGET_TICKS.to_f)
    { min: (low / step).floor * step, max: (high / step).ceil * step, step: }
  end

  # Snaps to a nice axis step (1, 2 or 5 times a power of ten).
  def nice_step(rough)
    return 1 if rough <= 0

    magnitude = 10**Math.log10(rough).floor
    fraction = rough / magnitude
    (NICE_STEPS.find { |step| fraction <= step } || 10) * magnitude
  end

  # Data points are plain numbers (line view) or [min, max] pairs (bar view)
  def chart_values
    datasets = data&.dig(:datasets)
    return [] unless datasets

    values = datasets.flat_map { |dataset| dataset[:data] }
    values.flatten!
    values.compact!
    values
  end
end

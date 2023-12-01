class Scale
  def initialize(max:, target: 0..100)
    @max = max || 0
    @target = target
  end

  attr_reader :max, :target

  def result(value)
    return 0 if value.nil? || value.zero?

    # Never exceed the upper bound!
    # This can happen if there is too little data to calculate the peak values.
    return upper_bound if value > max

    # Natural logarithm is not defined for negative numbers
    return lower_bound if value.negative?

    result =
      lower_bound +
        (extent * (Math.log(value)**FACTOR) / (Math.log(max)**FACTOR))

    if result.nan?
      # :nocov:
      Rails.logger.info "WARNING: Invalid input, cannot scale: value=#{value}, max=#{max}, target=#{target}"
      lower_bound
      # :nocov:
    else
      result.round
    end
  end

  private

  def lower_bound
    target.first
  end

  def upper_bound
    target.last
  end

  def extent
    target.size - 1
  end

  # Damping factor, play around to find the best one
  FACTOR = 6
  private_constant :FACTOR
end

class Scale
  def initialize(max:, target: 0..100)
    @max = max
    @target = target
  end

  attr_reader :max, :target, :value

  def result(value)
    return 0 if value.zero?

    target.first +
      (extent * (Math.log(value)**factor) / (Math.log(max)**factor)).round
  end

  private

  def extent
    target.size - 1
  end

  # Damping factor, play around to find the best one
  def factor
    6
  end
end

class Scale
  def initialize(max:, target: 0..100)
    @max = max || 0
    @target = target
  end

  attr_reader :max, :target, :value

  def result(value)
    return 0 if value.nil? || value.zero?

    target.first +
      (extent * (Math.log(value)**factor) / (Math.log(max)**factor)).round
  rescue StandardError => e
    Rails.logger.info "WARNING: Invalid input, cannot scale: value: #{value}, max: #{max}, error: #{e}"
    0
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

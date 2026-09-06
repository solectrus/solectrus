# Sits between the two columns of the balance sheet and speaks up when they do
# not match. Both sides describe the same energy, so a difference means a sensor
# misses a consumer or counts one twice.
class BalanceGap::Component < ViewComponent::Base
  def initialize(data:)
    super()
    @data = data
  end

  attr_reader :data

  def render?
    data.imbalance_relevant?
  end

  # Which side is too big. Each side allows two readings -- a sensor that misses
  # something, or one that measures too high -- so the direction alone does not
  # name the cause, and the explanation must offer both.
  def sources_exceed_sinks?
    data.imbalance.positive?
  end

  # Which of the two causes the reader gets to see. A battery loses energy on
  # every cycle, and that loss can only make the sinks look small -- so it
  # belongs in the explanation, but only where a battery exists.
  def explanation_key
    return '.explanation_sources' if sources_exceed_sinks?

    data.battery? ? '.explanation_sinks_battery' : '.explanation_sinks'
  end

  def sources
    format_energy(data.total_plus)
  end

  def sinks
    format_energy(data.total_minus)
  end

  def difference
    format_energy(data.imbalance)
  end

  # The share the threshold judges, so the reader sees what made this appear.
  def percent
    Sensor::ValueFormatter.new(
      data.imbalance_percent,
      unit: :percent,
      sign: true,
    ).to_s
  end

  private

  def format_energy(value)
    Sensor::ValueFormatter.new(value, unit: :watt, context: :total).to_s
  end
end

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

  def explanation_key
    sources_exceed_sinks? ? '.explanation_sources' : '.explanation_sinks'
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
  # The sign stays out: the difference above already names the direction.
  def percent
    Sensor::ValueFormatter.new(
      data.imbalance_percent.abs,
      unit: :percent,
    ).to_s
  end

  private

  def format_energy(value)
    Sensor::ValueFormatter.new(value, unit: :watt, context: :total).to_s
  end
end

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
    format_energy(energy.parts.first)
  end

  def sinks
    format_energy(-energy.parts.last)
  end

  def difference
    format_energy(energy.sum)
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

  # All three share the unit and the rounding, so they visibly add up. The unit
  # follows the difference, so it keeps its digits, but stays at least kWh, so
  # 12 kWh never show as 12000 Wh.
  def energy
    @energy ||=
      RoundedSum.new(
        [data.total_plus, -data.total_minus],
        unit: :watt,
        context: :total,
        scaling: [data.imbalance.abs, 1_000].max,
      )
  end

  def format_energy(value)
    Sensor::ValueFormatter.new(value, unit: :watt, **energy.options).to_s
  end
end

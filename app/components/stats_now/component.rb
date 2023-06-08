class StatsNow::Component < ViewComponent::Base
  def initialize(calculator:, field:)
    super
    @calculator = calculator
    @field = field
  end

  attr_accessor :calculator, :field

  def max_flow
    # Heuristic: The peak flow is the highest value of all fields
    @max_flow ||= peak.values.max
  end

  def timeframe
    Timeframe.now
  end

  def peak
    @peak ||=
      PowerPeak.new(
        fields: Senec::POWER_FIELDS,
        measurements: [Rails.configuration.x.influx.measurement_pv],
      ).result(start: 30.days.ago.beginning_of_day)
  end
end

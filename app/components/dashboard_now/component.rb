class DashboardNow::Component < ViewComponent::Base
  def initialize(calculator:)
    super
    @calculator = calculator
  end

  attr_accessor :calculator

  def max_flow
    # Heuristic: The peak flow is the highest value of all fields
    @max_flow ||= peak.values.max
  end

  def timeframe
    Timeframe.now
  end

  def peak
    @peak ||=
      begin
        result =
          PowerPeak.new(
            fields: Senec::POWER_FIELDS,
            measurements: %w[SENEC],
          ).result(start: 30.days.ago.beginning_of_day)
        Rails.logger.info "Peak: #{result.inspect}"

        result
      end
  end
end

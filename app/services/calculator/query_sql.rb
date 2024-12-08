class Calculator::QuerySql
  def initialize(calculations:, from: nil, to: nil)
    raise ArgumentError, 'No calculations given' if calculations.blank?

    @from = [from, Rails.application.config.x.installation_date].compact.max
    @to = to
    @calculations = calculations
  end

  attr_reader :from, :to, :calculations

  def time
    totals[:max_updated_at]&.in_time_zone
  end

  def respond_to_missing?(method, include_private = false)
    totals.key?(method) || super
  end

  def method_missing(method)
    totals.key?(method) ? totals[method] : super
  end

  private

  def totals
    @totals ||=
      Summary.where(date: from..to).calculate_all(
        *calculations,
        # Latest updated_at
        :max_updated_at,
      )
  end
end

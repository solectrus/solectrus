# What the comparison with a combustion car lacks (see Car::Comparison), so
# the page can say where its numbers fall short. Each gap has its key and a
# value where it has one: the number of the proposals, the kilometers
# without a cost or a fuel price, the cars without a tax. A complete
# comparison has no gap.
class Car::ComparisonGaps
  Gap = Data.define(:key, :value)
  public_constant :Gap

  def initialize(report)
    @report = report
    @comparison = report.comparison
  end

  def to_a = [proposals, unrated, splitter, payments, tax].compact

  private

  attr_reader :report, :comparison

  delegate :cars, to: :comparison

  # The offsite sessions that wait for a confirmation. Until then their cost
  # is missing.
  def proposals
    count = ChargingSession.proposals.where(car: cars, dismissed: false).on_dates(comparison.dates).count
    Gap.new(:proposals, count) if count.positive?
  end

  # The kilometers of the timeframe without a cost or a fuel price. The
  # comparison leaves them out on all sides.
  def unrated
    distance = (report.distance.to_f - comparison.distance).round
    Gap.new(:unrated, distance) if distance.positive?
  end

  # Without the power splitter, the energy of the wallbox has no PV share,
  # so all of it costs the electricity price. The build splits without a
  # look at the sponsorship, so the check does not look at it either.
  def splitter
    return unless Sensor::Config.exists?(:wallbox_power, check_policy: false)

    Gap.new(:splitter, nil) unless Sensor::Config.exists?(:wallbox_power_grid, check_policy: false)
  end

  # Without a payment in the dates of the comparison, the running costs hold
  # only the energy and the tax
  def payments
    Gap.new(:payments, nil) if comparison.payment_costs.empty?
  end

  # The cars whose combustion car has no tax
  def tax
    untaxed = cars.select { it.combustion_tax.to_f.zero? }
    Gap.new(:tax, untaxed) if untaxed.any?
  end
end

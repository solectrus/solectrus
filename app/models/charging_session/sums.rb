# The sums of a set of charging sessions, from one SQL aggregate (see
# ChargingSession.sums and .daily_sums). The energy is in kWh. A sum ignores a
# missing value, so the cost of a session without a cost counts as 0, and
# `uncosted` counts these sessions. `unsplit` counts the wallbox sessions
# without a grid share, because the power splitter was missing.
ChargingSession::Sums = Data.define(:count, :kwh, :kwh_grid, :cost, :cost_grid, :uncosted, :unsplit)

# The methods sit in a class body and not in the block of Data.define. A
# static index (Lint/ArgumentMismatch) puts a `def self.` of that block on
# Object, where it clashes with each other `sum`.
class ChargingSession::Sums
  # The SQL of each member, in the order of the members
  def self.sql
    [
      'COUNT(*)',
      'COALESCE(SUM(kwh), 0)',
      'COALESCE(SUM(kwh_grid), 0)',
      'COALESCE(SUM(cost), 0)',
      'COALESCE(SUM(cost_grid), 0)',
      'COUNT(*) FILTER (WHERE cost IS NULL)',
      "COUNT(*) FILTER (WHERE kind = 'wallbox' AND kwh_grid IS NULL)",
    ].map { Arel.sql(it) }
  end

  def self.from_row(row)
    count, kwh, kwh_grid, cost, cost_grid, uncosted, unsplit = row
    new(count:, kwh: kwh.to_f, kwh_grid: kwh_grid.to_f, cost: cost.to_f, cost_grid: cost_grid.to_f, uncosted:, unsplit:)
  end

  def self.empty = new(count: 0, kwh: 0.0, kwh_grid: 0.0, cost: 0.0, cost_grid: 0.0, uncosted: 0, unsplit: 0)

  # The sum of a list of Sums in one pass, without a Sums for each step
  def self.sum(list)
    return empty if list.empty?

    new(**members.index_with { |member| list.sum(&member) })
  end

  def any? = count.positive?
  def none? = !any?

  # Whether each session has a cost. A wallbox session has no cost on a
  # day without a price.
  def costed? = uncosted.zero?

  # Whether a session has a cost. Without a price for each of their days,
  # the sessions have none, and their sum of 0 is no cost.
  def cost? = uncosted < count

  # Whether each wallbox session has a grid share
  def split? = unsplit.zero?

  # The PV share of wallbox sessions: the energy and the cost that are not
  # the grid share. Nil without a split.
  def kwh_pv = (kwh - kwh_grid if split?)
  def cost_pv = (cost - cost_grid if split?)

  # The PV share in whole percent, nil without a split or energy
  def pv_percent
    (kwh_pv * 100 / kwh).round if split? && kwh.positive?
  end
end

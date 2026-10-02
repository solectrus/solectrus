# Car::ChargeSplit splits the charged energy and the charging cost of a set of
# charging sessions by source: PV and grid of the home wallbox, and offsite.
# Only the charge splits by source, never the distance (see docs/cars.md).
#
# A wallbox session stores its grid share, its cost and the cost of its grid
# share (see ChargingSession::Detection), so the split needs no price.
#
# Without the power splitter a wallbox session has no grid share, and there
# is no split.
class Car::ChargeSplit
  def initialize(sessions)
    @sessions = sessions
  end

  def split?
    wallbox.all?(&:kwh_grid)
  end

  # The energy (Wh) of the own wallbox, with or without a split
  def wallbox_wh = wh(wallbox.sum(&:kwh))

  # The charged energy (Wh) by source
  def energy
    return unless split?

    {
      pv: wh(wallbox.sum(&:kwh_pv)),
      grid: wh(wallbox.sum(&:kwh_grid)),
      offsite: wh(offsite.sum(&:kwh)),
    }
  end

  # The charging cost by source
  def cost
    return unless split?

    {
      pv: wallbox.sum { it.cost.to_f - it.cost_grid.to_f },
      grid: wallbox.sum { it.cost_grid.to_f },
      offsite: offsite.sum { it.cost.to_f },
    }
  end

  private

  attr_reader :sessions

  def wallbox
    @wallbox ||= sessions.select(&:wallbox?)
  end

  def offsite
    @offsite ||= sessions.select(&:offsite?)
  end

  def wh(kwh) = kwh.to_f * 1000.0
end

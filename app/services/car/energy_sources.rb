# The driven energy (Wh) and its cost by the source of the charged energy:
# the PV share and the grid share of the wallbox, and the offsite sessions
# (see Car::Driving#sources). The PV energy costs the lost feed-in tariff.
# The sources of days add up, like their energy and their cost.
Car::EnergySources = Data.define(:pv, :grid, :offsite)

# The methods sit in a class body, like those of ChargingSession::Sums
class Car::EnergySources
  # The energy (Wh) and the cost of one source
  Source =
    Data.define(:energy_wh, :cost) do
      def +(other) = with(energy_wh: energy_wh + other.energy_wh, cost: cost + other.cost)
    end
  public_constant :Source

  NONE = Source.new(energy_wh: 0.0, cost: 0.0)
  private_constant :NONE

  def self.empty = new(pv: NONE, grid: NONE, offsite: NONE)

  def +(other) = with(pv: pv + other.pv, grid: grid + other.grid, offsite: offsite + other.offsite)

  # { source => Source } of the sources with energy
  def present = to_h.select { |_, source| source.energy_wh.positive? }

  # The same energy without the PV system: the grid gives all the energy of
  # the wallbox, and an offsite session keeps its energy and its cost. So
  # the grid costs the rest of the cost without PV.
  def without_pv(cost)
    with(pv: NONE, grid: Source.new(energy_wh: pv.energy_wh + grid.energy_wh, cost: cost - offsite.cost))
  end
end

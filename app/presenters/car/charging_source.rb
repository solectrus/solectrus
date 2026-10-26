# How the car page and its charts show a source of the charged energy (see
# Car::Report#sources): its color, its icon and its label. Each source has
# a color of the car page (see sensor_colors.css), which the timeline, the
# bars of the figures and the charts share.
module Car::ChargingSource
  Style = Data.define(:color_class, :icon, :label_key) do
    # The CSS color behind the color class, for a part of a bar that paints
    # with a style instead of a class
    def color = "var(--color-#{color_class.delete_prefix('bg-')})"
  end
  private_constant :Style

  # The color classes stand in full, so Tailwind finds them
  STYLES = {
    pv: Style.new('bg-car-pv', 'sun', 'car_breakdown.home_pv'),
    grid: Style.new('bg-car-grid', 'bolt', 'car_breakdown.home_grid'),
    wallbox: Style.new('bg-car-wallbox', 'plug', 'car_breakdown.home'),
    offsite: Style.new('bg-car-offsite', 'charging-station', 'car_breakdown.offsite'),
  }.freeze
  private_constant :STYLES

  def self.[](key) = STYLES[key]

  # The sources of the energy of a session with their weight: PV and grid of
  # the wallbox with the power splitter, the wallbox alone without it, or
  # offsite. [[key, weight], ...]
  def self.of(session)
    return [[:offsite, 1]] if session.offsite?

    pv = session.kwh_pv&.to_f
    return [[:wallbox, 1]] if pv.nil? || session.kwh.to_f <= 0

    [[:pv, pv], [:grid, session.kwh_grid.to_f]].select { |_, value| value.positive? }.presence || [[:pv, 1]]
  end
end

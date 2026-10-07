# How the car page and its charts show a source of the charged energy (see
# Car::Report#sources): its color, its icon and its label
module Car::ChargingSource
  Style = Data.define(:sensor_name, :icon, :label_key) do
    # A source of the wallbox has the color of its sensor. Offsite charging
    # has no sensor.
    def color_class
      sensor_name ? Sensor::Registry[sensor_name].color_background : 'bg-sensor-offsite'
    end
  end
  private_constant :Style

  STYLES = {
    pv: Style.new(:wallbox_power_pv, 'sun', 'car_breakdown.home_pv'),
    grid: Style.new(:wallbox_power_grid, 'bolt', 'car_breakdown.home_grid'),
    wallbox: Style.new(:wallbox_power, 'plug', 'car_breakdown.home'),
    offsite: Style.new(nil, 'charging-station', 'car_breakdown.offsite'),
  }.freeze
  private_constant :STYLES

  def self.[](key) = STYLES[key]
end

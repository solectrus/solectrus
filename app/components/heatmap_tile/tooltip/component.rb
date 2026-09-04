class HeatmapTile::Tooltip::Component < ViewComponent::Base
  # The two parts of a grid balance. Each part takes the label of the sensor
  # that shows the same direction, and the sign it is shown with.
  GRID_FIELDS = {
    grid_revenue: {
      label: :grid_export_power,
      sign: :positive,
    },
    grid_costs: {
      label: :grid_import_power,
      sign: :negative,
    },
  }.freeze
  private_constant :GRID_FIELDS

  def initialize(value:, sensor:, date:, date_format: :default)
    super()
    @value = value
    @sensor = sensor
    @date = date
    @date_format = date_format
  end

  attr_reader :value, :sensor, :date, :date_format

  private

  def grid_power?
    sensor.name == :grid_power
  end

  def grid_balance
    @grid_balance ||= value[:grid_balance]
  end
end

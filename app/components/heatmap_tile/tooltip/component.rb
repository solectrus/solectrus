class HeatmapTile::Tooltip::Component < ViewComponent::Base
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

  def grid_fields
    %i[grid_revenue grid_costs]
  end

  def grid_balance
    return 0 unless value.is_a?(Hash)

    value[:grid_balance]
  end

  def label_for(field)
    field == :grid_revenue ? 'Export:' : 'Import:'
  end

  def sign_for(field)
    field == :grid_costs ? :negative : :positive
  end
end

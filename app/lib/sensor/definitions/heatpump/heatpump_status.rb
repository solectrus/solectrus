class Sensor::Definitions::HeatpumpStatus < Sensor::Definitions::Base
  value unit: :string, category: :status

  requires_permission :heatpump
end

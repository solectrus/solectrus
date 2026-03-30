class Sensor::Definitions::HeatpumpTankTempSetpoint < Sensor::Definitions::Base
  requires_permission :heatpump

  value unit: :celsius, category: :heatpump

  color background: 'bg-gray-400',
        text: 'text-white'
end

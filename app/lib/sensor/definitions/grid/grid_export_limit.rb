class Sensor::Definitions::GridExportLimit < Sensor::Definitions::Base
  value unit: :percent, range: (0..100), category: :grid
end

class Sensor::Definitions::CarConnected < Sensor::Definitions::Base
  include Sensor::Definitions::CarNumber

  value unit: :boolean, category: :car

  icon 'plug'

  # A car reports a change of its state, often only while it is online,
  # so the value holds until the next reading
  state

  requires_permission :car
end

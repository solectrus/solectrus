module Sensor
  # Everything that depends on the unit of a value -- how it is scaled, how it
  # is labelled, how many decimals it deserves -- lives in these definitions,
  # so that the formatters can stay free of unit-specific branches.
  module Units
    # Stands in for a sensor without a unit, and for anything unrecognized
    NULL = Null.new
    private_constant :NULL

    REGISTRY = {
      watt: Watt.new,
      gram: Gram.new,
      money: Money.new,
      money_per_kwh: MoneyPerKwh.new,
      celsius: Celsius.new,
      percent: Percent.new,
      unitless: Unitless.new,
      boolean: Boolean.new,
      string: Text.new,
    }.freeze
    private_constant :REGISTRY

    # All units a sensor may declare
    NAMES = REGISTRY.keys.freeze
    private_constant :NAMES

    def self.[](unit)
      REGISTRY.fetch(unit, NULL)
    end

    def self.names
      NAMES
    end
  end
end

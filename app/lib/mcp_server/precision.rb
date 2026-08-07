module McpServer
  # The single place that decides how precisely a value is serialized.
  #
  # Raw float arithmetic leaks digits that carry no information (170.6000...02
  # watts, 99.80449960264723 percent). Worse than the wasted bytes: when the
  # same sensor comes back rounded from one tool and unrounded from another, a
  # client cannot tell whether a value was rounded at all, and therefore cannot
  # decide whether further arithmetic on it is valid.
  #
  # So precision is keyed by the sensor's unit and by nothing else - not by the
  # tool, not by the sensor's own calculation. `list_sensors` publishes this
  # table in its `conventions` block, so a client knows the precision it is
  # getting instead of guessing.
  #
  # Deliberately not Sensor::Units, which answers a different question: its
  # #precision serves a localized display string, so it is a function of the
  # SCALED value (a watt gets a decimal only once it is a kW) and for money
  # even of the value's size. MCP rounds the raw value in its base unit, and
  # the decimals must be a function of the unit alone - that is what keeps one
  # array from mixing Integer and Float. Sensor::Units also has no entry for
  # the units aggregation introduces (watt_hour, watt_per_kwp).
  module Precision
    module_function

    # Decimals per unit. The unit is the MCP unit (see Tools::Base#mcp_unit),
    # so a summed watt sensor is rounded as the energy it has become.
    #
    # The values follow what the underlying measurement can actually resolve:
    # a watt is rarely a raw reading - series buckets are means, and many power
    # sensors are calculated from others - so a tenth keeps the fraction that
    # is genuinely there. Energy totals in Wh are dominated by measurement
    # error long before the first decimal, and a temperature or a percentage is
    # meaningless beyond a tenth. money_per_kwh is the exception that has to
    # stay fine: a tariff of 0.3271 currency/kWh rounded to 2 decimals is not a
    # rounding but a loss.
    DECIMALS = {
      watt: 1,
      watt_hour: 0,
      watt_per_kwp: 1,
      watt_hour_per_kwp: 0,
      money: 2,
      money_per_kwh: 4,
      percent: 1,
      celsius: 1,
      unitless: 2,
      gram: 0,
      gram_per_hour: 0,
    }.freeze
    public_constant :DECIMALS

    # The rounded value, with its JSON type determined by the unit alone: a
    # 0-decimal unit yields an Integer, any other a Float. That is what keeps
    # one array from mixing -26861 and -16783.0, and it drops the ".0" that
    # carries no information.
    #
    # Non-numeric values (booleans, strings, nil) and units without an entry
    # pass through untouched.
    def round(value, unit)
      return value unless value.is_a?(Numeric)

      decimals = DECIMALS[unit&.to_sym]
      return value if decimals.nil?

      decimals.zero? ? value.round : value.to_f.round(decimals)
    end
  end
end

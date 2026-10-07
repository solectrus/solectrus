# A sensor whose value is a text (unit :string), e.g. an inverter status
class Sensor::Units::Text < Sensor::Units::Base
  def parse(raw_value)
    raw_value.to_s
  end

  def format(printed_value, **)
    printed_value.to_s.to_utf8
  end
end

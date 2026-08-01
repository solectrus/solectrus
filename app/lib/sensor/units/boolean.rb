class Sensor::Units::Boolean < Sensor::Units::Base
  def format(printed_value, **)
    I18n.t(printed_value ? 'general.yes' : 'general.no')
  end
end

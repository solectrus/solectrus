class Sensor::Units::Base
  # Steps a value is scaled up by, largest last: the first step whose
  # threshold the value stays below wins. Empty for units that never scale.
  NO_STEPS = [].freeze
  private_constant :NO_STEPS

  def scale_steps
    NO_STEPS
  end

  def scalable?
    scale_steps.any?
  end

  # Whether values of this unit are read as an amount (Wh, kg, EUR) or as a
  # rate (W, g/h, EUR/h) unless the caller says otherwise.
  def default_context
    :rate
  end

  # The unit as printed, for the given scale prefix and context
  def label(**)
    ''
  end

  # Decimals the printed number deserves. Units whose readability depends on
  # the size of the number, or on how far it was scaled, override this.
  def precision(_printed_value, **)
    0
  end

  # How the value itself is printed
  def format(printed_value, precision:)
    ActionController::Base.helpers.number_with_precision(
      printed_value,
      precision:,
      delimiter: I18n.t('number.format.delimiter'),
      separator: I18n.t('number.format.separator'),
    )
  end

  private

  # A decimal is worth having for 12,3 kWh, but not for 123,4 kWh: a scaled
  # value drops it from 100 upwards.
  def decimal_while_short(printed_value)
    printed_value.abs >= 100 ? 0 : 1
  end
end

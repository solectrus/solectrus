class Number::Component < ViewComponent::Base
  def initialize(value:)
    super
    @value = value
  end

  attr_accessor :value

  def to_wh(max_precision: 1, unit: nil)
    raise ArgumentError unless unit.in?([:kilo, :mega, nil])
    return unless value

    if unit == :mega || (unit.nil? && value >= 1_000_000)
      styled_number(
        formatted_number(value / 1_000.0 / 1_000.0, max_precision: 1),
        unit: 'MWh',
      )
    else
      styled_number(
        formatted_number(value / 1_000.0, max_precision:),
        unit: 'kWh',
      )
    end
  end

  def to_w(max_precision: 1)
    return unless value

    styled_number(formatted_number(value / 1_000.0, max_precision:), unit: 'kW')
  end

  def to_eur(klass: nil)
    return unless value

    max_precision = value < 10 ? 2 : 0

    styled_number(
      formatted_number(value, max_precision:),
      unit: '€',
      klass: klass || (value.negative? ? %w[text-red-500] : %w[text-green-500]),
    )
  end

  def to_percent(max_precision: 1, klass: nil)
    return unless value

    styled_number(
      formatted_number(value, max_precision:),
      unit: '%',
      klass: klass || (value.positive? ? %w[text-green-500] : %w[text-red-500]),
    )
  end

  private

  def styled_number(number_as_string, unit:, klass: nil)
    return unless number_as_string

    parts = number_as_string.split(separator)

    tag.span class: klass do
      safe_join [
                  tag.strong(parts.first, class: 'font-medium'),
                  parts.second && tag.small("#{separator}#{parts.second}"),
                  '&nbsp;'.html_safe,
                  tag.small(unit),
                ]
    end
  end

  def formatted_number(value, max_precision:)
    return unless value

    # Some numbers don't need fractional digits
    need_fractional_digits =
      !value.round(max_precision).zero? && value.abs < 100

    number_with_precision(
      value,
      precision: need_fractional_digits ? max_precision : 0,
      delimiter: I18n.t('number.format.delimiter'),
      separator: I18n.t('number.format.separator'),
    )
  end

  def separator
    I18n.t('number.format.separator')
  end
end

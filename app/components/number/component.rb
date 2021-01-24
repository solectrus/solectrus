class Number::Component < ViewComponent::Base
  def initialize(value:)
    super
    @value = value
  end

  attr_accessor :value

  def to_kwh(max_precision: 1)
    return unless value

    styled_number(
      formatted_number(value / 1_000.0, max_precision: max_precision),
      unit: 'kWh'
    )
  end

  def to_kw(max_precision: 1)
    return unless value

    styled_number(
      formatted_number(value / 1_000.0, max_precision: max_precision),
      unit: 'kW'
    )
  end

  def to_eur(klass: nil)
    return unless value

    styled_number(
      formatted_number(value, max_precision: 2),
      unit: '€',
      klass: klass || (value.negative? ? %w[text-red-500] : %w[text-green-500])
    )
  end

  def to_percent(max_precision: 1, klass: nil)
    return unless value

    styled_number(
      formatted_number(value, max_precision: max_precision),
      unit: '%',
      klass: klass || (value.positive? ? %w[text-green-500] : %w[text-red-500])
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
        tag.small(unit)
      ]
    end
  end

  def formatted_number(value, max_precision:)
    return unless value

    # Some numbers don't need fractional digits
    need_fractional_digits = !value.round(max_precision).zero? && value.abs < 100

    number_with_precision(
      value,
      precision: need_fractional_digits ? max_precision : 0,
      delimiter: I18n.t('number.format.delimiter'),
      separator: I18n.t('number.format.separator')
    )
  end

  def separator
    I18n.t('number.format.separator')
  end
end

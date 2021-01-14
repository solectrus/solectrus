class Number::Component < ViewComponent::Base
  def initialize(value:)
    super
    @value = value
  end

  attr_accessor :value

  def to_kwh
    return unless value

    styled_number(
      formatted_number(value / 1_000.0, max_precision: 1),
      unit: 'kWh'
    )
  end

  def to_kw
    return unless value

    styled_number(
      formatted_number(value / 1_000.0, max_precision: 3),
      unit: 'kW'
    )
  end

  def to_eur
    return unless value

    styled_number(
      formatted_number(value, max_precision: 2),
      unit: '€',
      klass: value.negative? ? %w[text-red-500] : %w[text-green-500]
    )
  end

  def to_percent
    return unless value

    styled_number(
      formatted_number(value, max_precision: 1),
      unit: '%',
      klass: value.positive? ? %w[text-green-500] : %w[text-red-500]
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

    number_with_precision(
      value,
      precision: value >= 100 ? 0 : max_precision, # Large numbers don't need fractional digits
      delimiter: I18n.t('number.format.delimiter'),
      separator: I18n.t('number.format.separator')
    )
  end

  def separator
    I18n.t('number.format.separator')
  end
end

module ApplicationHelper
  def number_to_eur(value)
    return unless value

    string = number_to_currency(value, unit: '€', format: '%n %u', precision: value.abs < 100 ? 2 : 0)
    options = {
      class: value.negative? ? %w[text-red-500] : %w[text-green-500]
    }

    tag.span string, **options
  end

  def number_to_kwh(value)
    return unless value

    if value < 100 * 1_000
      string = number_with_precision(value / 1_000.0, precision: 1)
      parts = string.split(',')

      safe_join [
        tag.span(parts.first),
        tag.span(",#{parts.second}", class: 'text-base'),
        tag.span('&nbsp;kWh'.html_safe)
      ]
    else
      "#{number_with_precision(value / 1_000.0, precision: 0, delimiter: I18n.t('number.format.delimiter'))} kWh"
    end
  end

  def number_to_kw(value)
    return unless value

    string = number_with_precision(value / 1_000.0, precision: 3)
    parts = string.split(',')

    safe_join [
      tag.span(parts.first),
      tag.span(",#{parts.second}", class: 'text-base'),
      tag.span('&nbsp;kW'.html_safe)
    ]
  end

  def number_to_charge(value)
    return unless value

    string = number_to_percentage(value, precision: 1)
    options = {
      class: value.positive? ? %w[text-green-500] : %w[text-red-500]
    }

    tag.span string, **options
  end
end

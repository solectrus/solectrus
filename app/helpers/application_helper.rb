module ApplicationHelper
  def number_to_eur(value)
    return unless value

    string = number_to_currency(value, unit: '€', format: '%n %u')
    options = {
      class: value.negative? ? %w[text-red-500] : %w[text-green-500]
    }

    tag.span string, **options
  end

  def number_to_kwh(value)
    return unless value

    "#{number_with_precision(value / 1000.0, precision: 3)} kWh"
  end

  def number_to_kw(value)
    return unless value

    "#{number_with_precision(value / 1000.0, precision: 3)} kW"
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

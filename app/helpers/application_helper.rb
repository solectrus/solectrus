module ApplicationHelper
  def number_to_eur(value)
    string = number_to_currency(value, unit: '€', format: '%n %u')
    options = {
      class: value.negative? ? %w[text-red-500] : %w[text-green-500]
    }

    tag.span string, **options
  end

  def number_to_kwh(value)
    "#{number_with_precision(value, precision: 3)} kWh"
  end

  def number_to_kw(value)
    "#{number_with_precision(value, precision: 3)} kW"
  end
end

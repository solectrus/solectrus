class Number::Component < ViewComponent::Base
  def initialize(value:)
    super
    @value = value
  end

  attr_accessor :value

  def to_watt_hour(max_precision: 1, unit: determine_watt_unit)
    raise ArgumentError unless unit.in?(%i[single kilo mega])
    return unless value

    case unit
    when :single
      to_wh(max_precision: 0)
    when :kilo
      to_kwh(max_precision:)
    when :mega
      to_mwh(max_precision:)
    end
  end

  def to_watt(max_precision: 1, unit: determine_watt_unit)
    raise ArgumentError unless unit.in?(%i[single kilo mega])
    return unless value

    case unit
    when :single
      to_w(max_precision: 0)
    when :kilo
      to_kw(max_precision:)
    when :mega
      to_mw(max_precision:)
    end
  end

  def to_eur(max_precision: nil, klass: nil)
    return unless value

    max_precision ||= value.abs < 10 ? 2 : 0

    styled_number(
      formatted_number(value, max_precision:),
      unit: '&euro;'.html_safe,
      klass: klass || (value.negative? ? %w[text-red-500] : %w[text-green-500]),
    )
  end

  def to_weight(max_precision: 1, unit: determine_weight_unit)
    raise ArgumentError unless unit.in?(%i[single kilo tons])
    return unless value

    case unit
    when :single
      to_g(max_precision: 0)
    when :kilo
      to_kg(max_precision:)
    when :tons
      to_t(max_precision:)
    end
  end

  def to_eur_per_kwh(klass: nil)
    return unless value

    styled_number(
      formatted_number(value, max_precision: 4),
      unit: '&euro;/kWh'.html_safe,
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

  def to_grad_celsius(max_precision: 1)
    return unless value

    styled_number(
      formatted_number(value, max_precision:),
      unit: '&deg;C'.html_safe,
    )
  end

  private

  def determine_watt_unit
    return :mega if value >= 1_000_000
    return :kilo if value >= 100
    :single
  end

  def determine_weight_unit
    return :tons if value >= 1_000_000
    return :kilo if value >= 1000
    :single
  end

  def single(max_precision:)
    formatted_number(value, max_precision:)
  end

  def kilo(max_precision:)
    formatted_number(value / 1_000.0, max_precision:)
  end

  def mega(max_precision:)
    formatted_number(value / 1_000.0 / 1_000.0, max_precision:)
  end

  def to_w(max_precision:)
    styled_number(single(max_precision:), unit: 'W')
  end

  def to_kw(max_precision:)
    styled_number(kilo(max_precision:), unit: 'kW')
  end

  def to_mw(max_precision:)
    styled_number(mega(max_precision:), unit: 'MW')
  end

  def to_wh(max_precision:)
    styled_number(single(max_precision:), unit: 'Wh')
  end

  def to_kwh(max_precision:)
    styled_number(kilo(max_precision:), unit: 'kWh')
  end

  def to_mwh(max_precision:)
    styled_number(mega(max_precision:), unit: 'MWh')
  end

  def to_g(max_precision:)
    styled_number(single(max_precision:), unit: 'g')
  end

  def to_kg(max_precision:)
    styled_number(kilo(max_precision:), unit: 'kg')
  end

  def to_t(max_precision:)
    styled_number(mega(max_precision:), unit: 't')
  end

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
      value.round(max_precision).nonzero? && value.abs < 100

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

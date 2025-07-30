class Number::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  # TODO: Refactor this class to make it more readable and maintainable
  #
  # It would be better if the component would receive the number and unit and then
  # do the formatting via a method  like `to_html`, which is told the details
  # via parameters (precision, auto-precision, coloring, mega/kilo etc).

  def initialize(value:)
    super()
    @value = value
  end

  attr_accessor :value

  def to_watt_hour(max_precision: 1, unit: determine_watt_unit, precision: nil)
    raise ArgumentError unless unit.in?(%i[single kilo mega])
    return unless value

    case unit
    when :single
      to_wh
    when :kilo
      to_kwh(max_precision:, precision:)
    when :mega
      to_mwh(max_precision:, precision:)
    end
  end

  def to_watt(max_precision: 1, unit: determine_watt_unit, precision: nil)
    raise ArgumentError unless unit.in?(%i[single kilo mega])
    return unless value

    case unit
    when :single
      to_w
    when :kilo
      to_kw(max_precision:, precision:)
    when :mega
      to_mw(max_precision:, precision:)
    end
  end

  def to_eur(max_precision: nil, precision: nil, klass: nil, negative: false)
    return unless value

    max_precision ||= value.abs < 10 ? 2 : 0 unless precision
    negative ||= value.negative?

    styled_number(
      formatted_number(value, max_precision:, precision:),
      unit: '&euro;'.html_safe,
      klass: [
        klass,
        (
          if negative
            %w[text-red-700 dark:text-red-400]
          else
            %w[text-green-700 dark:text-green-400]
          end
        ),
      ],
    )
  end

  def to_weight(precision: nil, unit: determine_weight_unit, klass: nil)
    raise ArgumentError unless unit.in?(%i[single kilo tons])
    return unless value

    case unit
    when :single
      to_g(max_precision: 0, klass:)
    when :kilo
      to_kg(max_precision: 0, klass:)
    when :tons
      to_t(max_precision: 1, precision:, klass:)
    end
  end

  def to_eur_per_kwh(negative: nil, klass: nil)
    return unless value

    negative ||= value.negative?

    styled_number(
      formatted_number(value, max_precision: 4),
      unit: '&euro;/kWh'.html_safe,
      klass: [
        klass,
        (
          if negative
            %w[text-red-700 dark:text-red-400]
          else
            %w[text-green-700 dark:text-green-400]
          end
        ),
      ],
    )
  end

  def to_percent(max_precision: 1, precision: nil, klass: nil)
    return unless value

    styled_number(
      formatted_number(value, max_precision:, precision:),
      unit: '%',
      klass:
        klass ||
          (
            if value.positive?
              %w[text-green-500 dark:text-green-400]
            else
              %w[text-red-500 dark:text-red-400]
            end
          ),
    )
  end

  def to_grad_celsius(max_precision: 1, precision: nil)
    return unless value

    styled_number(
      formatted_number(value, max_precision:, precision:),
      unit: '&deg;C'.html_safe,
    )
  end

  private

  def determine_watt_unit
    return :mega if value >= 1_000_000
    return :kilo if value >= 1000

    :single
  end

  def determine_weight_unit
    return :tons if value >= 1_000_000
    return :kilo if value >= 1000

    :single
  end

  def single(max_precision:, precision: nil)
    formatted_number(value, max_precision:, precision:)
  end

  def kilo(max_precision:, precision: nil)
    formatted_number(value / 1_000.0, max_precision:, precision:)
  end

  def mega(max_precision:, precision: nil)
    formatted_number(value / 1_000.0 / 1_000.0, max_precision:, precision:)
  end

  def to_w
    styled_number(single(max_precision: 0, precision: 0), unit: 'W')
  end

  def to_kw(max_precision:, precision: nil)
    styled_number(kilo(max_precision:, precision:), unit: 'kW')
  end

  def to_mw(max_precision:, precision: nil)
    styled_number(mega(max_precision:, precision:), unit: 'MW')
  end

  def to_wh
    styled_number(single(max_precision: 0, precision: 0), unit: 'Wh')
  end

  def to_kwh(max_precision:, precision: nil)
    styled_number(kilo(max_precision:, precision:), unit: 'kWh')
  end

  def to_mwh(max_precision:, precision: nil)
    styled_number(mega(max_precision:, precision:), unit: 'MWh')
  end

  def to_g(max_precision:, precision: nil, klass: nil)
    styled_number(single(max_precision:, precision:), unit: 'g', klass:)
  end

  def to_kg(max_precision:, precision: nil, klass: nil)
    styled_number(kilo(max_precision:, precision:), unit: 'kg', klass:)
  end

  def to_t(max_precision:, precision: nil, klass: nil)
    styled_number(mega(max_precision:, precision:), unit: 't', klass:)
  end

  def styled_number(number_as_string, unit:, klass: nil)
    return unless number_as_string

    parts = number_as_string.split(separator)

    tag.span class: klass do
      safe_join [
                  tag.strong(parts.first, class: 'font-medium'),
                  parts.second && tag.small("#{separator}#{parts.second}"),
                  '&nbsp;'.html_safe,
                  (tag.small(unit) if unit),
                ]
    end
  end

  def formatted_number(value, max_precision:, precision: nil)
    return unless value

    unless precision
      # Some numbers don't need fractional digits
      need_fractional_digits =
        value.round(max_precision).nonzero? && value.abs < 100

      precision = need_fractional_digits ? max_precision : 0
    end

    number_with_precision(
      value,
      precision:,
      delimiter: I18n.t('number.format.delimiter'),
      separator: I18n.t('number.format.separator'),
    )
  end

  def separator
    I18n.t('number.format.separator')
  end
end

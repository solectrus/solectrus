# The look of the comparison with a combustion car: the cards, the colors of
# the columns and the formats of the numbers (see
# Car::ComparisonPage::Component, Car::ComparisonChart::Component and
# Car::FuelPriceChart::Component). Each format gives HTML, so a template
# shows a number the same way, with a link or without one (see
# Car::ComparisonLinks).
module Car::ComparisonFormat
  # A card of the page. A phone has a gray page, so its cards are white, like
  # a grouped list. A desktop has a white page, and the sections stand on it
  # without a card, apart by space.
  CARD = 'max-lg:rounded-2xl max-lg:bg-white dark:max-lg:bg-slate-800/60'.freeze
  public_constant :CARD

  # The color of each column of the comparison: the car, the car without PV
  # and the combustion car. The green is the signal color of the savings
  # above, and the car without PV has a dark green beside it. The combustion
  # car has a muted red of its own (sensor_colors.css).
  COLORS = {
    car: 'bg-signal-positive',
    without_pv: 'bg-ev-without-pv',
    combustion: 'bg-combustion',
  }.freeze
  public_constant :COLORS

  # The motion of the parts of the car without PV, when a button of the page
  # adds the car or takes it away (see Car::ComparisonPage::Component). CSS
  # animates them alone.
  MOTION = 'duration-300 ease-glide motion-reduce:transition-none'.freeze
  public_constant :MOTION

  # A part of the car without PV keeps its place and fades
  WITHOUT_PV_FADE = "invisible opacity-0 transition-[opacity,visibility] #{MOTION} group-data-without-pv/comparison:visible group-data-without-pv/comparison:opacity-100".freeze
  public_constant :WITHOUT_PV_FADE

  # The title of a column. Beside the car without PV, the car names its PV
  # system with a suffix.
  def column_title(column)
    return column.title unless column.suffix

    helpers.safe_join([column.title, helpers.tag.span(" #{column.suffix}", class: 'hidden group-data-without-pv/comparison:inline')])
  end

  # The series of a chart of the columns (see
  # Car::ComparisonPage::Component::Column), in their order and colors: the
  # key names the column, the label and its suffix come from its title, and
  # the block gives the values of a key
  def column_series(columns) = columns.map { { key: it.key, label: it.title, suffix: it.suffix, values: yield(it.key) }.compact }

  def column_colors(columns) = columns.map { COLORS[it.key] }

  # An amount in whole units, also below 10, so a column of amounts has no
  # decimals. A rate or a price asks for its precision.
  def money(value, precision: 0, **) = render(Sensor::Value::Component.new(value, :total_costs, precision:, **))

  def currency(value, precision: 0) = helpers.number_to_currency(value, precision:, unit: Currency.symbol)

  # A price per liter, nil without one
  def per_liter(value) = ("#{currency(value, precision: 2)}/l" if value)

  # The info icon beside a title, with notes as paragraphs. It stays in the
  # flow, but must be relative, so its touch target is centered on it and
  # does not cover the page.
  def info_icon(notes, position: nil) = Ui::InfoIcon::Component.new(text: notes.join("\n\n"), position: helpers.class_names('relative', position))

  # The color of a saving: green for a gain, red for a loss
  def savings_color_of(amount) = amount.negative? ? 'text-signal-negative' : 'text-signal-positive'

  # A number without a sensor, its decimals small like those of a sensor
  # value (see Sensor::Value::Component)
  def decimal_number(value, precision:)
    separator = I18n.t('number.format.separator')
    integer, decimal = helpers.number_with_precision(value, precision:, delimiter: I18n.t('number.format.delimiter')).split(separator)
    parts = [helpers.tag.strong(integer, class: 'font-medium'), (helpers.tag.small("#{separator}#{decimal}", class: 'sensor-value-decimal') if decimal)]
    helpers.tag.span(class: 'sensor-value') { helpers.tag.span(helpers.safe_join(parts.compact), class: 'sensor-value-number') }
  end
end

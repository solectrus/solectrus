# The charging of the selected cars (see CarSelectable) in a column for each
# day, month or year: the charged energy or the charging cost of their
# charging sessions. A guest session and a session that is not assigned count
# for no car.
#
# A column stacks by source: PV and grid of the own wallbox with the power
# splitter, the wallbox alone without it, and the offsite sessions. Several
# cars add up in these parts, without a part for each car.
class Sensor::Chart::CarSessions < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarColumns

  # The frontend adds up the parts of these stacks in the tooltip
  STACKS = { energy: 'CarCharging', cost: 'CarChargingCosts' }.freeze
  public_constant :STACKS

  # The sensor of the chart, and the sensor and label of each source
  MEASURES = {
    energy: {
      sensor: :car_charging,
      pv: [:wallbox_power_pv, 'splitter.pv'],
      grid: [:wallbox_power_grid, 'splitter.grid'],
      wallbox: :wallbox_power,
    },
    cost: {
      sensor: :car_charging_costs,
      pv: [:wallbox_costs_pv, 'sensors.opportunity_costs'],
      grid: [:wallbox_costs_grid, 'sensors.grid_costs'],
      wallbox: :wallbox_costs,
    },
  }.freeze
  private_constant :MEASURES

  # `measure` is :energy or :cost
  def initialize(measure:, **)
    super(**)
    @measure = measure
  end

  attr_reader :measure

  def chart_sensor_names
    [MEASURES.dig(measure, :sensor)]
  end

  # A period without a charging session is no gap in the data, because the
  # car can drive on the energy of an earlier charge. Sessions without a
  # price have no cost, so their period has no cost, but it has charged.
  def blank_message
    I18n.t(unpriced? ? 'data.car_no_charging_cost' : 'data.car_no_charging')
  end

  def blank_icon = ('plug' unless unpriced?)

  # A cost is a finance chart, like the cost of the wallbox
  def permitted_feature_name
    :finance_charts if measure == :cost
  end

  private

  def build_data
    return if columns.empty?

    { labels:, datasets: source_datasets }
  end

  # From the bottom up, like the sources of the report (see
  # Car::Report#sources). Each column has the same sources.
  def source_datasets
    datasets =
      columns.map { report.sources(dates: it) }.transpose.map do |parts|
        id, label, color_class = source_style(parts.first.key)
        dataset(id, label, parts.map { presence(value(it)) }, color_class)
      end
    notes = cost_notes
    notes ? datasets.map { it.merge(tooltipNotes: notes) } : datasets
  end

  # The note of each column of the cost with a session without a price: its
  # cost is too small. The tooltip reads the notes of its first part, so each
  # part gets them.
  def cost_notes
    return unless measure == :cost

    notes = columns.map { [I18n.t('charging_sessions.cost_incomplete')] unless report.sessions(dates: it).costed? }
    notes if notes.any?
  end

  # Whether the sessions of the cost chart have no price at all
  def unpriced?
    return false unless measure == :cost

    sessions = report.sessions
    sessions.any? && !sessions.cost?
  end

  # The id, the label and the color of the dataset of a source
  def source_style(key)
    color_class = Car::ChargingSource[key].color_class

    case key
    when :offsite
      ['offsite', ChargingSession.human_enum_name(:kind, :offsite), color_class]
    when :wallbox
      [MEASURES.dig(measure, :wallbox), Sensor::Registry[:wallbox_power].display_name, color_class]
    else
      sensor_name, label_key = MEASURES.dig(measure, key)
      [sensor_name, I18n.t(label_key), color_class]
    end
  end

  # The energy (Wh) or the cost of a source of a column
  def value(source)
    measure == :energy ? source.kwh * 1000 : source.cost
  end

  def dataset(id, label, data, color_class)
    style_for_sensor(chart_sensors.first).merge(id: id.to_s, label:, data:, stack: STACKS[measure], summed: true, colorClass: color_class)
  end
end

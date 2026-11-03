# The charging of a period as a card of the overview of the car page (see
# Car::PeriodOverview::Component): the charged energy, below it a bar of the
# sources, and the energy cost. The tooltip of each source has its energy,
# its share and its cost. Without the power splitter, the wallbox has no PV
# and grid, so the bar has the wallbox and the offsite sessions. The numbers
# are the charging sessions of the selected cars (see Car::Report).
#
# The link to the sessions names the sessions that the numbers leave out: on
# "all" the wallbox sessions that are not assigned, which count for no car,
# and for the admin the proposals of the offsite sessions. Without them the
# numbers would be too small without a reason.
class Car::PeriodOverview::Charging::Component < ViewComponent::Base
  # `all` is whether the page shows "all" and not one selected car
  def initialize(report:, all: false)
    super()
    @report = report
    @all = all
  end

  attr_reader :report

  delegate :timeframe, :split?, to: :report

  def total_kwh = report.sessions.kwh

  def energy_value(kwh, precision: total_kwh >= 100 ? 0 : 1)
    Sensor::Value::Component.new(kwh * 1000, :wallbox_power, context: :total, scaling: :kilo, precision:)
  end

  # The sources with energy in the order of the bar, PV first. Without
  # charged energy there is none.
  def sources
    @sources ||= total_kwh.positive? ? report.sources.select { it.kwh.positive? } : []
  end

  # The charged energy, which the card names, so it needs no tooltip
  def energy_figure
    Car::Figure.new(sensor_name: :car_charging, value: render(energy_value(total_kwh)))
  end

  # The sources of the bar. Each one loads the chart of the charged energy,
  # and its tooltip has its own energy, share and cost.
  def segments
    sources.map do |source|
      Car::PeriodOverview::Card::Component::Segment.new(figure: source_figure(source), weight: source.kwh, css: Car::ChargingSource[source.key].card_class)
    end
  end

  # The cells of the card: the cost, which the card names, and the link to
  # the sessions, if any (see #list)
  def cells = [Car::PeriodOverview::Card::Component::Cell.new(figure: cost_figure), list].compact

  # The cost, which the title of its tooltip names, with the cost of each
  # source as a sum: each one after the first with a plus sign, and the cost
  # with an equals sign below them. The cost of the guest is a part of the
  # cost, so it has neither.
  def cost_figure
    figure = plain_cost_figure
    sources = figure.parts.select(&:color)
    return figure unless sources.many?

    summands = sources.map { it == sources.first ? it : it.with(value: safe_join(['+ ', it.value])) }
    total = Car::Tooltip::Component::Part.new(label: t('.total'), value: safe_join(['= ', figure.value]))
    figure.with(parts: [*summands, total, *figure.parts.reject(&:color)])
  end

  # The link to the list of the sessions, with the sessions that the numbers
  # leave out (see ChargingSession::Review). It opens the kind of such
  # sessions, whose list offers them alone. A period without charging and
  # without such sessions has none.
  def list
    return @list if defined?(@list)

    notes = review_notes
    return @list = nil if sources.none? && notes.none?

    kind = notes.keys.first || ChargingSession.listed_kinds.first
    @list = Car::PeriodOverview::Card::Component::List.new(label: t('charging_sessions.title'), href: sessions_path(kind), sheet_href: sessions_path(kind, sheet: 1), notes: notes.values)
  end

  # A period without charging says so. Sessions that the numbers leave out
  # keep the figures with 0, beside the link that names them (see
  # Car::PeriodOverview::Card::Component#blank?).
  def empty = (Car::PeriodOverview::Card::Component::Empty.new(icon: 'charging-station', text: t('.none')) if sources.none?)

  # The note of the sessions to review of each kind that has some
  def review_notes
    {
      'wallbox' => (t('car_breakdown.unassigned', count: unassigned_count) if unassigned_count.positive?),
      'offsite' => (t('car_breakdown.unconfirmed', count: proposal_count) if proposal_count.positive?),
    }.compact
  end

  # The list of the sessions in the timeframe and with the car of the page
  def sessions_path(kind, **)
    helpers.cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: helpers.selection_params[:car], **)
  end

  private

  # A source with its icon, its energy, its share and its cost, which its
  # label names (see #cost_label_key)
  def source_figure(source)
    style = Car::ChargingSource[source.key]
    energy = render(energy_value(source.kwh))
    cost = report.sessions.cost?
    parts = [
      Car::Tooltip::Component::Part.new(label: t('sensors.car_charging'), value: energy),
      Car::Tooltip::Component::Part.new(label: t('.share'), value: "#{share_of(source.key)} %"),
      (Car::Tooltip::Component::Part.new(label: t(cost_label_key(source.key)), value: currency(source.cost)) if cost),
    ].compact
    Car::Figure.new(sensor_name: :car_charging, value: energy, title: t(style.label_key), icon: style.icon, parts:)
  end

  # The cost of a source by what it is: the grid costs of the grid, the lost
  # feed-in revenue of PV and the price paid offsite. The wallbox without the
  # power splitter mixes PV and grid, so its cost is the energy cost.
  COST_LABEL_KEYS = { pv: 'sensors.opportunity_costs', grid: 'sensors.grid_costs', offsite: '.offsite_cost' }.freeze
  private_constant :COST_LABEL_KEYS

  def cost_label_key(key) = COST_LABEL_KEYS.fetch(key, 'sensors.car_charging_costs')

  # The whole share of the source, rounded so the shares add up to 100
  def share_of(key)
    @shares ||= sources.map(&:key).zip(LargestRemainder.round(sources.map { it.kwh * 100 / total_kwh })).to_h
    @shares.fetch(key, 0)
  end

  # Sessions without a price have no cost, so their sum of 0 is no number. A
  # cost without the cost of each session is a minimum with a sign. The
  # tooltip has the cost of each source, the cost of the guest, and why the
  # cost is a minimum.
  def plain_cost_figure
    sessions = report.sessions
    cost = (safe_join([('≥ ' unless sessions.costed?), render(Sensor::Value::Component.new(sessions.cost, :total_costs))]) if sessions.cost?)
    Car::Figure.new(sensor_name: :car_charging_costs, title: t('.cost_title'), value: cost || '–', parts: cost_parts, notes: cost_notes(sessions))
  end

  # Why the cost is a minimum
  def cost_notes(sessions) = [(t('charging_sessions.cost_incomplete') if sessions.cost? && !sessions.costed?)].compact

  # The cost of each source in the color of the bar, and on "all" the cost
  # of the guest, which the cost holds. A single source without the guest
  # would repeat the cost.
  def cost_parts
    @cost_parts ||=
      if report.sessions.cost? && (sources.many? || guest_cost)
        [
          *sources.map { source_part(it) },
          (Car::Tooltip::Component::Part.new(label: t('.guest'), value: currency(guest_cost)) if guest_cost),
        ].compact
      else
        []
      end
  end

  def source_part(source)
    Car::Tooltip::Component::Part.new(label: t(Car::ChargingSource[source.key].label_key), value: currency(source.cost), color: Car::ChargingSource[source.key].color)
  end

  # The cost of the guest sessions, which "all" holds, or nil
  def guest_cost
    return unless @all

    guest = report.guest_sessions
    guest.cost if guest.cost? && guest.cost.positive?
  end

  def currency(value) = Sensor::ValueFormatter.new(value, unit: Sensor::Registry[:total_costs].unit).to_s

  # The wallbox sessions that are not assigned. "all" names them, because its
  # numbers leave them out. They can be the charge of any car or of the guest,
  # so each selection names them for the admin.
  def unassigned_count = @all || helpers.admin? ? report.unassigned_sessions.count : 0

  # The proposals, which only the admin sees
  def proposal_count = helpers.admin? ? report.proposal_count : 0
end

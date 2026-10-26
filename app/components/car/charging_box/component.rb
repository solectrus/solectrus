# The charging of a period in the overview of the car page (see
# Car::OverviewBox::Component): the charged energy with the energy of each
# source in its tooltip, the share of PV, and the charging cost. The swatch
# before the title shows the shares of the sources. Without the power
# splitter, the wallbox has no PV and grid, so the swatch has the wallbox and
# the offsite sessions. The numbers are the charging sessions of the selected
# cars (see Car::Report).
#
# The link to the sessions names the sessions that the numbers leave out: on
# "all" the wallbox sessions that are not assigned, which count for no car,
# and for the admin the proposals of the offsite sessions. Without them the
# numbers would be too small without a reason.
class Car::ChargingBox::Component < ViewComponent::Base
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

  # The shares of the sources of the period, like a bar of a charge in the
  # timeline of a day. A period without charging has no color.
  def swatch
    return [Car::OverviewBox::Component::NEUTRAL] if sources.none?

    sources.map { Car::OverviewBox::Component::Segment.new(percent: it.kwh * 100 / total_kwh, color: Car::ChargingSource[it.key].color) }
  end

  def parts
    sources.map do |source|
      Car::OverviewBox::Component::Part.new(label: t(Car::ChargingSource[source.key].label_key), value: render(energy_value(source.kwh)), color: Car::ChargingSource[source.key].color, percent: share_of(source.key))
    end
  end

  # The source whose share counts: PV, even at 0 %. Without the power
  # splitter it is the wallbox, but only next to offsite sessions, where its
  # share says something.
  def share_key
    if split?
      :pv
    elsif sources.many?
      :wallbox
    end
  end

  # The charged energy with the energy of each source in its tooltip, the
  # share of PV or of the wallbox, and the charging cost. The title of the
  # group says "charging", so the caption of the cost on a phone leaves it
  # out.
  def figures
    [
      Car::OverviewBox::Component::Figure.new(sensor_name: :car_charging, label: t('car_breakdown.charged'), value: render(energy_value(total_kwh)), parts:),
      share_figure,
      cost_figure,
    ].compact
  end

  # The link to the list of the sessions, with the sessions that the numbers
  # leave out (see ChargingSession::Review). It opens the kind of such
  # sessions, whose list offers them alone. A period without charging and
  # without such sessions has none.
  def list
    notes = review_notes
    return if sources.none? && notes.none?

    kind = notes.keys.first || ChargingSession.listed_kinds.first
    Car::OverviewBox::Component::List.new(label: t('charging_sessions.title'), href: sessions_path(kind), sheet_href: sessions_path(kind, sheet: 1), notes: notes.values)
  end

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

  # The whole share of the source, rounded so the shares add up to 100
  def share_of(key)
    @shares ||= sources.map(&:key).zip(LargestRemainder.round(sources.map { it.kwh * 100 / total_kwh })).to_h
    @shares.fetch(key, 0)
  end

  # Sessions without a price have no cost, so their sum of 0 is no number. A
  # cost without the cost of each session is a minimum with a sign. The
  # tooltip has the cost of each source, the cost of the guest, and why the
  # cost is a minimum.
  def cost_figure
    sessions = report.sessions
    cost = (safe_join([('≥ ' unless sessions.costed?), render(Sensor::Value::Component.new(sessions.cost, :total_costs))]) if sessions.cost?)
    Car::OverviewBox::Component::Figure.new(sensor_name: :car_charging_costs, label: t('car_breakdown.cost'), wide_label: t('sensors.car_charging_costs'), value: cost || '–', parts: cost_parts, notes: cost_notes(sessions))
  end

  # What the cost of PV means, beside the parts, and why the cost is a minimum
  def cost_notes(sessions)
    [
      (t('.pv_cost') if cost_parts.any? && sources.any? { it.key == :pv }),
      (t('charging_sessions.cost_incomplete') if sessions.cost? && !sessions.costed?),
    ].compact
  end

  # The cost of each source in the color of the bar, and on "all" the cost
  # of the guest, which the cost holds. A single source without the guest
  # would repeat the cost.
  def cost_parts
    @cost_parts ||=
      if report.sessions.cost? && (sources.many? || guest_cost)
        [
          *sources.map { source_part(it) },
          (Car::OverviewBox::Component::Part.new(label: t('.guest'), value: currency(guest_cost), color: nil, percent: nil) if guest_cost),
        ].compact
      else
        []
      end
  end

  def source_part(source)
    Car::OverviewBox::Component::Part.new(label: t(Car::ChargingSource[source.key].label_key), value: currency(source.cost), color: Car::ChargingSource[source.key].color, percent: nil)
  end

  # The cost of the guest sessions, which "all" holds, or nil
  def guest_cost
    return unless @all

    guest = report.guest_sessions
    guest.cost if guest.cost? && guest.cost.positive?
  end

  def currency(value) = Sensor::ValueFormatter.new(value, unit: Sensor::Registry[:total_costs].unit).to_s

  # The share of the source. The swatch shows the shares of all sources, and
  # the tooltip of the energy beside it the energy of each source.
  def share_figure
    return unless share_key

    Car::OverviewBox::Component::Figure.new(sensor_name: :car_charging, label: t("car_breakdown.share_#{share_key}"), value: share_text(share_key))
  end

  def share_text(key) = sources.any? ? "#{share_of(key)} %" : '–'

  # The wallbox sessions that are not assigned. "all" names them, because its
  # numbers leave them out. They can be the charge of any car or of the guest,
  # so each selection names them for the admin.
  def unassigned_count = @all || helpers.admin? ? report.unassigned_sessions.count : 0

  # The proposals, which only the admin sees
  def proposal_count = helpers.admin? ? report.proposal_count : 0
end

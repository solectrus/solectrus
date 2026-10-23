# The charging of a period in the overview of the car page (see
# Car::OverviewBox::Component): the charged energy, a ring of its sources with
# the share of PV in the center, and the energy of each source. Below, the
# charging cost. Without the power splitter, the wallbox has no PV and grid,
# so the ring has the wallbox and the offsite sessions. The numbers are the
# charging sessions of the selected cars (see Car::Report).
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

  def value_label = "#{t('sensors.car_charging')} #{Sensor::ValueFormatter.new(total_kwh * 1000, unit: Sensor::Registry[:wallbox_power].unit, context: :total, scaling: :kilo)}"

  # The sources with energy in the order of the ring, PV first. Without
  # charged energy there is none.
  def sources
    @sources ||= total_kwh.positive? ? report.sources.select { it.kwh.positive? } : []
  end

  def segments
    sources.map { Car::OverviewBox::Component::Segment.new(percent: it.kwh * 100 / total_kwh, color: "var(#{Car::ChargingSource[it.key].color_var})") }
  end

  def parts
    sources.map do |source|
      Car::OverviewBox::Component::Part.new(label: t(Car::ChargingSource[source.key].label_key), value: render(energy_value(source.kwh)), color: "var(#{Car::ChargingSource[source.key].color_var})", percent: share_of(source.key))
    end
  end

  # The whole share in the center of the ring and its label: PV, the share
  # that counts, even at 0 %. Without the power splitter it is the wallbox,
  # but only next to offsite sessions, where its share says something. A
  # ring without charging stays empty.
  def center
    return [nil, nil] unless center_key && sources.any?

    ["#{share_of(center_key)} %", t("car_breakdown.share_#{center_key}")]
  end

  def center_key
    if split?
      :pv
    elsif sources.many?
      :wallbox
    end
  end

  def head
    center_value, center_label = center
    Car::OverviewBox::Component::Head.new(sensor_name: :car_charging, label: value_label, value: render(energy_value(total_kwh)), segments:, center: center_value, center_label:, parts:)
  end

  def figures = [cost_figure]

  # The tiles of a phone: the charged energy with the energy of each source
  # in its tooltip, the share of PV or of the offsite sessions, and the
  # charging cost
  def tiles
    [
      Car::OverviewBox::Component::Figure.new(sensor_name: :car_charging, label: t('car_breakdown.charged'), value: render(energy_value(total_kwh)), parts:),
      share_tile,
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

    Car::OverviewBox::Component::List.new(label: t('charging_sessions.title'), href: sessions_path(*notes.keys.first), icon: 'charging-station', notes: notes.values)
  end

  # The note of the sessions to review of each kind that has some
  def review_notes
    {
      'wallbox' => (t('car_breakdown.unassigned', count: unassigned_count) if unassigned_count.positive?),
      'offsite' => (t('car_breakdown.unconfirmed', count: proposal_count) if proposal_count.positive?),
    }.compact
  end

  # The list of the sessions in the timeframe and with the car of the page
  def sessions_path(kind = ChargingSession.listed_kinds.first)
    helpers.cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: helpers.selection_params[:car])
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
    cost = ("#{'≥ ' unless sessions.costed?}#{currency(sessions.cost)}" if sessions.cost?)
    Car::OverviewBox::Component::Figure.new(sensor_name: :car_charging_costs, label: t('sensors.car_charging_costs'), value: cost || '–', parts: cost_parts, notes: cost_notes(sessions))
  end

  # What the cost of PV means, beside the parts, and why the cost is a minimum
  def cost_notes(sessions)
    [
      (t('.pv_cost') if cost_parts.any? && sources.any? { it.key == :pv }),
      (t('charging_sessions.cost_incomplete') if sessions.cost? && !sessions.costed?),
    ].compact
  end

  # The cost of each source in the color of the ring, and on "all" the cost
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
    Car::OverviewBox::Component::Part.new(label: t(Car::ChargingSource[source.key].label_key), value: currency(source.cost), color: "var(#{Car::ChargingSource[source.key].color_var})", percent: nil)
  end

  # The cost of the guest sessions, which "all" holds, or nil
  def guest_cost
    return unless @all

    guest = report.guest_sessions
    guest.cost if guest.cost? && guest.cost.positive?
  end

  def currency(value) = Sensor::ValueFormatter.new(value, unit: Sensor::Registry[:total_costs].unit).to_s

  # The center of the ring as a tile. The energy of each source is in the
  # tooltip of the energy beside it.
  def share_tile
    return unless center_key

    Car::OverviewBox::Component::Figure.new(sensor_name: :car_charging, label: t("car_breakdown.share_#{center_key}").upcase_first, value: share_text(center_key))
  end

  def share_text(key) = sources.any? ? "#{share_of(key)} %" : '–'

  # The wallbox sessions that are not assigned. "all" names them, because its
  # numbers leave them out. They can be the charge of any car or of the guest,
  # so each selection names them for the admin.
  def unassigned_count = @all || helpers.admin? ? report.unassigned_sessions.count : 0

  # The proposals, which only the admin sees
  def proposal_count = helpers.admin? ? report.proposal_count : 0
end

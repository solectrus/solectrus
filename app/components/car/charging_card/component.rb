# The charging of a period: the charged energy with the energy of each source
# in its tooltip, a ring of the sources with the share of PV in the center,
# and the number of wallbox, offsite and guest sessions. The tooltip of the ring
# gives the share and the cost of each source and the charging cost. Without
# the power splitter, the wallbox has no PV and grid, so the ring has the
# wallbox and the offsite sessions. The numbers are the charging sessions of
# the selected cars (see Car::Report). A guest session belongs to no car, so
# only "all" adds the guest sessions, and names them in a badge of their own
# and in the tooltip of the ring.
#
# A badge with sessions that its count leaves out shows an icon, and its
# tooltip names them (see #omitted).
class Car::ChargingCard::Component < ViewComponent::Base
  include CarChartLink

  # A part of the ring below this share would be a hairline
  MIN_PERCENT = 0.3
  private_constant :MIN_PERCENT

  # Each badge with its sessions and the list it opens. Without a wallbox
  # there is no wallbox or guest session, and their badges are hidden, not
  # zero. A selected car hides the guest badge.
  Badge = Data.define(:kind, :sums, :params)
  private_constant :Badge

  # The sessions that the count of a badge leaves out, with their energy
  # where it counts for nothing, and their list
  Omitted = Data.define(:text, :kwh, :path)
  private_constant :Omitted

  # A source of the charged energy (see Car::Report#sources) with its style,
  # its share in percent and its whole share
  Part = Data.define(:source, :style, :percent, :whole_percent)
  private_constant :Part

  # `all` is whether the page shows "all" and not one selected car
  def initialize(report:, all: false)
    super()
    @report = report
    @all = all
  end

  attr_reader :report

  delegate :timeframe, :cars, :split?, to: :report

  # The tag and the options of the charged energy, with the energy of each
  # source in its tooltip. It loads the chart of the charged energy, or is a
  # plain block where the timeframe has no such chart: a day without a
  # wallbox has no curve of the charging power. A tap on a link opens the
  # chart, so its tooltip needs a long press, and a tap on a plain block opens
  # the tooltip (like Car::StatRow::Component). `link_class` applies to the
  # link alone.
  def charging_wrapper(**)
    data =
      if parts.any?
        {
          controller: 'tooltip',
          tooltip_placement_value: 'bottom',
          tooltip_force_tap_to_close_value: false,
          tooltip_touch_value: charging_chart ? 'long' : 'true',
        }
      else
        {}
      end
    chart_wrapper(charging_chart, data:, **)
  end

  def charging_chart = chart_sensor_name(:car_charging)

  def charging_costs_chart = chart_sensor_name(:car_charging_costs)

  # Sessions without a price have no cost, so their sum of 0 is no number
  def charging_cost = (charged.cost if charged.cost?)

  def total_kwh = charged.kwh

  # The sources with energy in the order of the ring, PV first. Without
  # charged energy there is none.
  def parts
    @parts ||= total_kwh.positive? ? build_parts : []
  end

  # The parts of the ring. Each loads the chart of the charged energy.
  def donut_segments
    parts.filter_map do |part|
      next if part.percent < MIN_PERCENT

      { percent: part.percent, color_var: part.style.color_var, label: t(part.style.label_key), sensor_name: charging_chart }
    end
  end

  def donut_url = (chart_link_url(charging_chart) if charging_chart)

  def donut_chart_url = (chart_url(charging_chart) if charging_chart)

  # The whole share in the center of the ring and its label: PV, the share
  # that counts, even at 0 %. Without the power splitter it is the wallbox,
  # but only next to offsite sessions, where its share says something.
  # Without charged energy there is no share (see the template).
  def center_share
    return if parts.none?

    key = split? ? :pv : (:wallbox if parts.many?)
    return unless key

    [parts.find { it.source.key == key }&.whole_percent || 0, t("car_breakdown.share_#{key}")]
  end

  # The cost of each source, rounded so the parts add up to the charging cost
  def costs
    @costs ||= Car::ChargingTooltip::Component::Costs.of(report.sources.to_h { [it.key, it.cost] })
  end

  # The share and the cost of each source, and the charging cost. Sessions
  # without a price have no cost at all, so their sum of 0 is no number.
  def donut_tooltip
    Car::ChargingTooltip::Component.new(
      sources: parts.map { Car::ChargingTooltip::Component::Source.new(key: it.source.key, whole_percent: it.whole_percent) },
      costs: (costs if charged.cost?),
      guest_cost: (report.guest_sessions.cost if guest_cost?),
      complete: charged.costed?,
    )
  end

  def energy_value(kwh, precision: self.precision, **)
    SensorValue::Component.new(kwh * 1000, :wallbox_power, context: :total, scaling: :kilo, precision:, **)
  end

  # The guest has no badges: its sessions stand beside its cost (see
  # the template)
  def badges
    return [] if report.guest_only?

    car = report.car&.id
    [
      (Badge.new(:wallbox, wallbox, { kind: 'wallbox', car: }) if wallbox?),
      Badge.new(:offsite, offsite, { kind: 'offsite', car: }),
      (guest_badge if wallbox? && @all),
    ].compact
  end

  # Two badges share the width, one or three take a third each
  def badge_grid_class = badges.size == 2 ? 'grid-cols-2' : 'grid-cols-3'

  # A cell of the guest below the ring: its charging cost or its sessions
  def guest_cell_classes
    'flex flex-col items-center gap-1 min-w-0 px-2 text-center focus:outline-none focus-visible:rounded-lg focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400'
  end

  def guest_value_classes
    'text-3xl md:text-4xl font-semibold leading-none tabular-nums whitespace-nowrap text-slate-700 dark:text-slate-200'
  end

  # The sessions that the count of the badge leaves out, or nil: the
  # proposals of the offsite sessions, and on "all" the wallbox sessions that
  # are not assigned. These count for no car, so without the hint the numbers
  # of "all" are too small without a reason.
  def omitted(badge)
    case badge.kind
    when :offsite
      count = report.proposal_count
      Omitted.new(t('car_breakdown.unconfirmed', count:), nil, sessions_path('offsite', CarSelection::PROPOSALS)) if count.positive?
    when :wallbox
      sessions = report.unassigned_sessions
      Omitted.new(t('car_breakdown.unassigned', count: sessions.count), sessions.kwh, sessions_path('wallbox', CarSelection::UNASSIGNED)) if @all && sessions.any?
    end
  end

  def sessions_path(kind, car) = helpers.cars_charging_sessions_path(kind:, timeframe:, car:)

  def badge_cost(badge, **)
    SensorValue::Component.new(badge.sums.cost, :total_costs, **)
  end

  def badge_classes = [Car::Card::Component::BADGE, 'bg-slate-200 dark:bg-slate-700/60']

  private

  def charged = report.sessions

  # The wallbox sessions of the cars, without the guest, which has a badge of
  # its own
  def wallbox = report.sessions(:wallbox, guest: false)

  def offsite = report.sessions(:offsite)

  def guest_badge = Badge.new(:guest, report.guest_sessions, { kind: 'wallbox', car: CarSelection::GUEST })

  def wallbox?
    Sensor::Config.exists?(:wallbox_power)
  end

  def guest_cost? = @all && report.guest_sessions.any?

  def build_parts
    sources = report.sources.select { it.kwh.positive? }
    whole_percents = LargestRemainder.round(sources.map { it.kwh * 100 / total_kwh })

    sources.zip(whole_percents).map do |source, whole_percent|
      Part.new(source:, style: Car::ChargingSource[source.key], percent: source.kwh * 100 / total_kwh, whole_percent:)
    end
  end

  # From 100 kWh on, a decimal adds nothing
  def precision
    total_kwh >= 100 ? 0 : 1
  end
end

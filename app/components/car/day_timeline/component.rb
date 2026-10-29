# The day of the selected cars (see Car::DayTimeline), below the figures of
# a day on the car page. Each car has a timeline of its own: its drives as
# bars, its charges as bars split by the sources of their energy, and its
# state of charge as a line. A bar says when, its tooltip says how much (see
# Car::TimelineBar::Component). Each timeline has its axis (see
# Car::DayTimeline::Axis).
#
# The running day ends at now: a dashed line marks it, and the rest of the
# day stays empty.
class Car::DayTimeline::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  include Car::DayTimeline::DriveBars
  include Car::DayTimeline::ChargeAreas

  Part = Car::OverviewBox::Component::Part
  private_constant :Part

  Bar = Car::TimelineBar::Bar
  private_constant :Bar

  # The color of a drive, also in the swatch of the driving (see
  # Car::DrivingBox::Component)
  DRIVE_COLOR = 'var(--color-car-drive)'.freeze
  public_constant :DRIVE_COLOR

  PLUGGED_COLOR = 'var(--color-car-plugged)'.freeze
  private_constant :PLUGGED_COLOR

  # `named` names the car also on a single timeline, for "all" on a page that
  # offers a select: the select names no car then
  def initialize(timeline:, named: false)
    super()
    @timeline = timeline
    @named = named
  end

  attr_reader :timeline

  delegate :lanes, to: :timeline
  delegate :now, to: :axis

  # The labels of the axis, the same below each timeline
  def ticks = @ticks ||= axis.ticks

  # The box while the timeline loads, in its height
  def self.placeholder = new(timeline: nil)

  def placeholder? = timeline.nil?

  # Several timelines name their car or the guest, and so does "all"
  def named_lanes? = @named || lanes.many?

  def lane_name(lane) = lane.guest? ? t('.guest') : lane.car.display_name

  # A single timeline with a state of charge fills the rest of the window on
  # a phone, so the line grows into the space below. The placeholder fills
  # it too, because a single car is the common case. Several timelines keep
  # their heights, and the window scrolls.
  def fills? = placeholder? || (lanes.one? && lanes.first.soc?)

  def fill_class = ('max-lg:flex-1' if fills?)

  # At least the height of a fixed row, so a small phone scrolls
  def soc_height_class = fills? ? 'min-h-28 max-lg:flex-1 lg:h-36' : 'h-28 lg:h-36'

  # A bar for each charging session, from its start to its end, with the
  # tooltip of the session. A charge at the wallbox draws its power inside
  # the bar (see Car::DayTimeline::ChargeAreas). A pause in which the car
  # stayed plugged in is a grey part of the bar, so the energy of the
  # session stands once. Like the time plugged in, a charge that runs on at
  # now or over midnight is open at that end, and a charge from before
  # midnight is open at its start.
  def charge_bars(lane)
    lane.charges.map do |charge|
      session = charge.session
      from, to = charge.span
      left, right = [from, to].map { axis.position(it) }
      open = session.ongoing? || right >= 100
      continued = left.zero?

      Bar.new(
        from: left,
        to: right,
        segments: Car::ChargingSource.of(session).map { |key, weight| [Car::ChargingSource[key].color, weight] },
        areas: charge_areas(charge),
        pauses: charge.pauses.map { pause_in(it, charge.span) },
        ends: ends(from, to, lane.plugged, jagged: charge.estimated?, open:, continued:),
        title: t(session.offsite? ? '.charge_offsite' : '.charge_wallbox'),
        lines: [time_text((from unless continued), (to unless open)), *offsite_place(session)].compact,
        parts: charge_parts(session),
        notes: charge_notes(charge),
        **charge_links(session),
      )
    end
  end

  # A grey bar for each time in which the car was plugged in but did not
  # charge, below the bars of the charges. A time that runs on at now or
  # over midnight is open at that end, so its bar is square there and its
  # tooltip names no end. A time plugged in before midnight is open at its
  # start.
  def plugged_bars(lane)
    charges = lane.charges.map(&:span)
    lane.plugged.map do |from, to|
      left, right = [from, to].map { axis.position(it) }
      open = timeline.now?(to) || right >= 100
      Bar.new(
        from: left,
        to: right,
        segments: [[PLUGGED_COLOR, 1]],
        ends: ends(from, to, charges, open:, continued: left.zero?),
        title: t('.plugged'),
        lines: [plugged_time(from, to, charges, open:, continued: left.zero?)].compact,
      )
    end
  end

  def soc_label(lane) = t('.soc_label', from: lane.soc_line.first.from_value.round, to: lane.soc_line.last.to_value.round)

  # The line of the state of charge as SVG paths in a box of 1000 x 100 (see
  # Car::DayTimeline::SocLine): the known pieces, and the dashed pieces where
  # the readings leave open when the value changed
  def soc_paths(lane)
    known, unknown = lane.soc_line.partition(&:known)
    [known, unknown].map do |segments|
      segments.map { "M#{soc_point(it.from, it.from_value)} L#{soc_point(it.to, it.to_value)}" }.join(' ')
    end
  end

  # The area below the whole line, down to 0 %
  def soc_area(lane)
    points = lane.soc_line.flat_map { [soc_point(it.from, it.from_value), soc_point(it.to, it.to_value)] }
    "M#{soc_point(lane.soc_line.first.from, 0)} L#{points.join(' L')} L#{soc_point(lane.soc_line.last.to, 0)} Z"
  end

  # The pieces of the line that take time, each a bar without segments with
  # its tooltip: a flat run of the same whole percent, or a change, like the
  # rise of a charge. A step takes no time and has no tooltip of its own. An
  # estimate, which the line draws dashed, says so in its tooltip.
  def soc_bars(lane)
    pieces = lane.soc_line.select { it.to > it.from }
    runs = pieces.chunk_while { |before, after| flat?(before) && flat?(after) && before.known == after.known && before.from_value.round == after.from_value.round }

    runs.map { soc_bar(it.first.from, it.last.to, it.first.from_value.round, it.last.to_value.round, estimated: !it.first.known) }
  end

  # A dotted line of the time grid at a label inside the day, every three
  # hours on the desktop, every six on a phone
  def grid_classes(tick)
    class_names(
      'pointer-events-none absolute inset-y-0 border-l border-dotted border-line',
      'hidden' => tick.position <= 0 || tick.position >= 100,
      'max-lg:hidden' => !tick.major,
    )
  end

  # The first label stands at the start, the last one ends at the end, and
  # each other one stands in the middle of its time
  def tick_classes(tick, index)
    class_names(
      'absolute top-0',
      '-translate-x-full' => index.positive? && tick.position >= 100,
      '-translate-x-1/2' => index.positive? && tick.position < 100,
      'max-lg:hidden' => !tick.phone,
      'lg:hidden' => !tick.desktop,
    )
  end

  private

  def axis = @axis ||= Car::DayTimeline::Axis.new(timeline.timeframe)

  # A point of the line in the box of 1000 x 100
  def soc_point(time, value) = "#{(axis.position(time) * 10).round(2)} #{(100 - value.clamp(0, 100).to_f).round(2)}"

  # Whether a piece of the line keeps its whole percent
  def flat?(segment) = segment.from_value.round == segment.to_value.round

  # Like the time plugged in, a value from before midnight names no start,
  # and a value that holds at now or over midnight names no end
  def soc_bar(from, to, from_value, to_value, estimated: false)
    value = from_value == to_value ? from_value : "#{from_value} → #{to_value}"
    lines = [time_text((from if axis.position(from).positive?), (to if axis.position(to) < 100 && !timeline.now?(to)))].compact
    Bar.new(from: axis.position(from), to: axis.position(to), title: t('.soc_value', value:), lines:, notes: (estimated ? [t('.soc_estimated')] : []))
  end

  # Why the time of a charge is an estimate, and where a charge from the day
  # before counts, like in the figures above the timeline. A pause needs no
  # note, because its grey part of the bar shows it.
  def charge_notes(charge) = [(t('.estimated') if charge.estimated?), (t('.started_before') if charge.session.started_at < timeline.timeframe.beginning)].compact

  # A pause as [left, width] in percent of the time of its charge
  def pause_in((pause_from, pause_to), (from, to))
    [pause_from - from, pause_to - pause_from].map { (it * 100.0 / (to - from)).round(3) }
  end

  # The looks of the start and the end of a bar from `from` to `to`. An end
  # that touches one of the `others`, a charge and the time plugged in beside
  # it, is square, so the two bars read as one time plugged in. An `open` end
  # runs on, and a `continued` start comes from the day before, so they are
  # square too. An estimated end is jagged.
  def ends(from, to, others, jagged: false, open: false, continued: false)
    last = open || others.any? { it.first == to } ? :square : :round
    [continued || others.any? { it.last == from } ? :square : :round, jagged ? :jagged : last]
  end

  # The time of a bar, the first line below its title: from its start to its
  # end, since its start without an end, like where it runs on, or until its
  # end without a start, like where it is not known. Without both, the bar
  # has no time. The note of an estimated time tells it (see #charge_notes).
  def time_text(from, to)
    if from && to then axis.range(from, to)
    elsif from then t('.since', from: axis.clock(from))
    elsif to then t('.until', to: axis.clock(to))
    end
  end

  # The times of a time plugged in that no other bar tells: not the end of
  # the charge before it, nor the start of the charge after it, nor an open
  # end
  def plugged_time(from, to, charges, open:, continued:)
    time_text((from unless continued || charges.any? { it.last == from }), (to unless open || charges.any? { it.first == to }))
  end

  # The energy, the state of charge, the cost and the PV share. The title
  # names the wallbox or offsite, so the share of the grid needs no row of
  # its own. A session without the power splitter has no share.
  def charge_parts(session)
    [
      detail(t('.energy'), Sensor::ValueFormatter.new(session.kwh.to_f * 1000, unit: Sensor::Registry[:wallbox_power].unit, context: :total, scaling: :kilo).to_s),
      soc_part(session.soc_from, session.soc_to),
      (detail(t('.cost'), Sensor::ValueFormatter.new(session.cost, unit: Sensor::Registry[:total_costs].unit).to_s) if session.cost),
      pv_part(session),
    ].compact
  end

  def pv_part(session)
    percent = session.pv_percent if session.wallbox?
    detail(t('.pv_share'), "#{percent} %") if percent
  end

  # The form of an offsite session, which the admin opens with a click: in
  # the modal on the desktop, in a sheet on a phone. Its list of the day is
  # where the form goes back to.
  def charge_links(session)
    return {} unless session.offsite? && helpers.admin?

    {
      href: helpers.edit_cars_charging_session_path(session, return_to: day_list_path(session)),
      sheet_href: helpers.edit_cars_charging_session_path(session, sheet: 1, return_to: day_list_path(session, sheet: 1)),
    }
  end

  def day_list_path(session, **params)
    helpers.cars_charging_sessions_path(kind: 'offsite', timeframe: timeline.timeframe.to_param, car: session.car_id, **params)
  end

  # Where an offsite session charged, like on the map of the sessions (see
  # ChargingSession::Spot#name_lines). The place is personal data, so only
  # the admin reads it.
  def offsite_place(session)
    return [] unless session.offsite? && helpers.admin?

    ChargingSession::Spot.new(sessions: [session]).name_lines
  end

  def soc_part(from, to)
    detail(t('.soc'), t('.soc_change', from: from.round, to: to.round)) if from && to
  end

  # A part of a tooltip without a color
  def detail(label, value) = Part.new(label:, value:, color: nil, percent: nil)
end

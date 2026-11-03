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
  include Car::DayTimeline::ChargeFill
  include Car::DayTimeline::SocCurve

  Part = Car::Tooltip::Component::Part
  private_constant :Part

  Bar = Car::TimelineBar::Bar
  private_constant :Bar

  # The color of a drive, like the chart of the distance
  DRIVE_COLOR = 'var(--color-car-drive)'.freeze
  public_constant :DRIVE_COLOR

  PLUGGED_COLOR = 'var(--color-car-plugged)'.freeze
  private_constant :PLUGGED_COLOR

  # `named` names the car also on a single timeline, for "all" on a page that
  # offers a select: the select names no car then. The timeline stands beside
  # the cards of the day (see Car::PeriodOverview::Component), in the place
  # of the chart of a period.
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

  # Whether the timeline has a title: beside the cards only the name of its
  # car, which a single car leaves out
  def heading?(lane) = lane && named_lanes?

  # A single timeline with a state of charge fills the height of the cards,
  # and on a phone the rest of the window, so the line grows into the space.
  # A single timeline that only charges, like the guest, fills it with the
  # row of the charging. The placeholder fills it, because a single car is
  # the common case. Several timelines keep their heights on a phone, and
  # the window scrolls. On the desktop, each of them with a state of charge
  # grows into the height of the cards.
  def fills? = placeholder? || (lanes.one? && (lanes.first.soc? || charging_only?(lanes.first)))

  def charging_only?(lane) = !lane.soc? && !lane.driving?

  # Without a lane, the class of the box around all timelines
  def fill_class(lane = nil)
    if fills?
      'flex-1'
    elsif lane ? lane.soc? : lanes.any?(&:soc?)
      'lg:flex-1'
    end
  end

  # The rows of the charging and of the drives are high like the bars of a
  # chart
  def row_height_class = 'h-10 lg:h-12'

  def row_gap_class = 'gap-3 lg:gap-4'

  # The row of the charging grows when it is the only row that fills
  def charging_height_class(lane) = fills? && charging_only?(lane) ? growing_height_class : row_height_class

  # The row that grows: the state of charge, or the charging alone. At least
  # the height of a fixed row, so a small phone scrolls.
  def growing_height_class = fills? ? 'min-h-16 flex-1' : 'h-28 lg:h-auto lg:min-h-36 lg:flex-1'

  # A bar for each charging session, from its start to its end, with the
  # tooltip of the session and its fill (see Car::DayTimeline::ChargeFill).
  # Like the time plugged in, a charge that runs on at now or over midnight
  # is open at that end, and a charge from before midnight is open at its
  # start.
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
        **charge_fill(charge),
        jagged: [false, charge.estimated?],
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
  # over midnight is open at that end, so its tooltip names no end. A time
  # plugged in before midnight is open at its start.
  def plugged_bars(lane)
    charges = lane.charges.map(&:span)
    lane.plugged.map do |from, to|
      left, right = [from, to].map { axis.position(it) }
      open = timeline.now?(to) || right >= 100
      Bar.new(
        from: left,
        to: right,
        segments: [[PLUGGED_COLOR, 1]],
        title: t('.plugged'),
        lines: [plugged_time(from, to, charges, open:, continued: left.zero?)].compact,
      )
    end
  end

  def soc_label(lane) = t('.soc_label', from: lane.soc_line.first.from_value.round, to: lane.soc_line.last.to_value.round)

  # The line of the state of charge as SVG paths in a box of 1000 x 100 (see
  # Car::DayTimeline::SocCurve): the known pieces, and the dashed pieces where
  # the readings leave open when the value changed. Pieces that meet run on
  # in one path, so their corners join.
  def soc_paths(lane)
    known, unknown = soc_curve(lane).partition(&:known)
    [known, unknown].map do |segments|
      segments.chunk_while { |before, after| before.to == after.from && before.to_value == after.from_value }.map do |run|
        "M#{soc_point(run.first.from, run.first.from_value)} L#{run.map { soc_point(it.to, it.to_value) }.join(' L')}"
      end.join(' ')
    end
  end

  # The area below the whole line, down to 0 %
  def soc_area(lane)
    curve = soc_curve(lane)
    points = curve.flat_map { [soc_point(it.from, it.from_value), soc_point(it.to, it.to_value)] }
    "M#{soc_point(curve.first.from, 0)} L#{points.join(' L')} L#{soc_point(curve.last.to, 0)} Z"
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

  # Why the time of a charge is an estimate, why a part of it is dotted, and
  # where a charge from the day before counts, like in the figures above the
  # timeline. A pause needs no note, because its grey part of the bar shows
  # it.
  def charge_notes(charge)
    [
      (t('.estimated') if charge.estimated?),
      (t('.gap') if charge.gaps.any?),
      (t('.started_before') if charge.session.started_at < timeline.timeframe.beginning),
    ].compact
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

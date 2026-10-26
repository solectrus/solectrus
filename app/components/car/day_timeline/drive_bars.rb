# The bars of the drives of the timeline of a day (see
# Car::DayTimeline::Component), with their tooltips
module Car::DayTimeline::DriveBars
  # A bar for each drive. A time that the readings leave open has a jagged
  # edge and a note: an estimated start after a gap in the readings (see
  # Car::DayTimeline::Drives::Drive#earliest_at), a time that does not fit
  # the distance, or no start at all.
  def drive_bars(lane)
    lane.drives.map do |drive|
      Car::TimelineBar::Bar.new(
        from: axis.position(drive.start),
        to: axis.position(drive.ended_at),
        segments: [[Car::DayTimeline::Component::DRIVE_COLOR, 1]],
        ends: drive_ends(drive),
        title: t('.drive'),
        lines: [time_text(drive.started_at || drive.earliest_at, drive.ended_at), *route(lane, drive)],
        parts: drive_parts(lane, drive),
        notes: drive_notes(drive),
      )
    end
  end

  private

  # A window of the readings is open at both ends, a start that is too late
  # or an estimate at its start
  def drive_ends(drive)
    if drive.window? then %i[jagged jagged]
    elsif drive.estimated_start? || drive.too_fast? then %i[jagged round]
    else %i[round round]
    end
  end

  def drive_notes(drive)
    [
      (t('.start_estimated') if drive.estimated_start?),
      (t('.start_unknown') if drive.unknown_start?),
      (t('.window') if drive.window?),
      (t('.too_fast') if drive.too_fast?),
    ].compact
  end

  # The state of charge before and after the drive. With an estimated start,
  # the value there stands in, and without a start the value before the
  # reading of the drive.
  def drive_parts(lane, drive)
    before = lane.soc_at(drive.started_at || drive.earliest_at || (drive.ended_at - 1.second))
    after = lane.soc_at(drive.ended_at)

    [
      detail(t('.distance'), Sensor::ValueFormatter.new(drive.distance, unit: Sensor::Registry[:car_distance].unit).to_s),
      soc_part(before, after),
    ].compact
  end

  # The start and the goal of a drive, which only the admin sees (see
  # Car::DayTimeline). A missing one is a dash.
  def route(lane, drive)
    places = [lane.origin(drive), lane.goal(drive)]
    return [] if places.none?

    [places.map { it ? it.display_name || t('car_breakdown.unknown_place') : '–' }.join(' → ')]
  end
end

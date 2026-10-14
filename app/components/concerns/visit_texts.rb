# The times of a visit as text, for the row of the list of the visits, which
# reads `visit`
module VisitTexts
  extend ActiveSupport::Concern
  include TimeRangeText

  # The start and the end of the visit. A visit over midnight names the day
  # of its end as well, like the day of the row, and its year only when the
  # year changes. An ongoing visit has no end yet.
  def time_range
    started_at = visit.started_at.in_time_zone
    return t('visits.since', time: started_at.strftime('%H:%M')) if visit.ongoing?

    time_range_text(started_at, visit.ended_at.in_time_zone) { moment(it, started_at.to_date) }
  end

  # [line, note] of the visit in the list of one day: the line names the
  # times on the day, and the note the start or the end outside it, or nil.
  # An ongoing visit has no end yet.
  def day_times(day)
    started_at = visit.started_at.in_time_zone
    ended_at = visit.ended_at.in_time_zone
    before = started_at.to_date < day
    after = ended_at.to_date > day

    if before && (after || visit.ongoing?)
      [t('visits.all_day'), span(day)]
    elsif before
      [t('visits.until', time: ended_at.strftime('%H:%M')), t('visits.since', time: moment(started_at, day))]
    elsif after
      [t('visits.from', time: started_at.strftime('%H:%M')), end_after(day)]
    else
      [time_range, nil]
    end
  end

  private

  # The start and the end of a visit over the whole day
  def span(day)
    since = moment(visit.started_at.in_time_zone, day)
    return t('visits.since', time: since) if visit.ongoing?

    "#{since} – #{moment(visit.ended_at.in_time_zone, day)}"
  end

  # The end of a visit after the day
  def end_after(day)
    return t('visits.until_now') if visit.ongoing?

    t('visits.until', time: moment(visit.ended_at.in_time_zone, day))
  end

  # The day and the time, with the year only when it differs from the year of
  # the reference day
  def moment(time, reference)
    time.strftime(time.year == reference.year ? '%d.%m. %H:%M' : '%d.%m.%Y %H:%M')
  end
end

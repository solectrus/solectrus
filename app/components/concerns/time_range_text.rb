# The start and the end of a charging session or a visit: both times on the
# same day, otherwise the start and the block with the end
module TimeRangeText
  extend ActiveSupport::Concern

  def time_range_text(started_at, ended_at)
    from = started_at.strftime('%H:%M')
    return "#{from}–#{ended_at.strftime('%H:%M')}" if ended_at.to_date == started_at.to_date

    "#{from} – #{yield ended_at}"
  end
end

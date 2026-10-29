# The time of a reading of a car as text, in the live view. A car sensor
# holds its value at any age, so the live view always tells how old it is:
# the time of today, "Yesterday" and the time, the weekday and the time
# within the last six days, or else the date and the time. Within six days,
# no weekday comes twice, so the weekday is clear. A car in the live view
# shows the age of its reading instead (see Car::LiveCard::Component).
module Car::TimeText
  def time_text(time)
    return unless time

    case day_of(time)
    when :today then l(time, format: :now)
    when :yesterday then t('cars.time.yesterday', time: l(time, format: :now))
    when :weekday then t('cars.time.weekday', day: l(time, format: '%A'), time: l(time, format: :now))
    else l(time, format: :short)
    end
  end

  # How the day of a time is named: today, yesterday, by its weekday within
  # the last six days, or else by its date
  def day_of(time)
    if time.today? then :today
    elsif time.yesterday? then :yesterday
    elsif time.to_date > 7.days.ago.to_date then :weekday
    else :date
    end
  end

  # How long ago a reading came: just now, in minutes, in hours, or in days.
  # The live view refreshes it with its values.
  def time_ago_text(time)
    return unless time

    minutes = ((Time.current - time) / 60).floor
    if minutes < 1
      t('cars.time.just_now')
    elsif minutes < 60
      t('cars.time.minutes_ago', count: minutes)
    elsif minutes < 24 * 60
      t('cars.time.hours_ago', count: minutes / 60)
    else
      t('cars.time.days_ago', count: minutes / (24 * 60))
    end
  end
end

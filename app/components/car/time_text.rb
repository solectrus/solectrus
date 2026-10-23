# The time of a reading of a car as text, in the live view. A car sensor
# holds its value at any age, so the live view always tells how old it is:
# the time of today, "Yesterday" and the time, the weekday and the time
# within the last six days, or else the date and the time. Within six days,
# no weekday comes twice, so the weekday is clear.
module Car::TimeText
  def time_text(time)
    return unless time

    if time.today?
      l(time, format: :now)
    elsif time.yesterday?
      t('cars.time.yesterday', time: l(time, format: :now))
    elsif time.to_date > 7.days.ago.to_date
      t('cars.time.weekday', day: l(time, format: '%A'), time: l(time, format: :now))
    else
      l(time, format: :short)
    end
  end
end

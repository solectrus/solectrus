# A duration as text: the hours and the minutes, like "8:50 h", or the minutes
# alone below an hour, like "45 min". A long time stays in hours, like
# "62:05 h", so the durations of a list compare at a glance. The lists of the
# visits and of the places and the map of the places show the time that a car
# stood at a place with it.
module DurationText
  def self.call(seconds)
    minutes = (seconds / 60.0).round
    return I18n.t('cars.duration.minutes', count: minutes) if minutes < 60

    hours, minutes = minutes.divmod(60)
    I18n.t('cars.duration.hours', time: "#{ActiveSupport::NumberHelper.number_to_delimited(hours, locale: I18n.locale)}:#{format('%02d', minutes)}")
  end
end

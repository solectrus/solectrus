# A duration as text with its two largest units: "2 days 5 h", "3 h 20 min"
# or "20 min". The map of the places and the list of the places show the time
# that a car stood at a place with it.
module DurationText
  def self.call(seconds)
    minutes = (seconds / 60.0).round
    days, minutes = minutes.divmod(24 * 60)
    hours, minutes = minutes.divmod(60)

    parts = days.positive? ? { days:, hours: } : { hours:, minutes: }
    parts = { minutes: } if days.zero? && hours.zero?

    parts.filter_map { |unit, count| I18n.t("cars.duration.#{unit}", count:) if count.positive? || parts.one? }.join(' ')
  end
end

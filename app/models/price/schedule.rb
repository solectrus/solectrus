# The electricity and the feed-in price of any date, from one query for all
# prices, not one query for each day. A price is valid from its start date.
# The query runs when the schedule is made, so #at needs no database.
class Price::Schedule
  def initialize
    # { name => [[date, value], ...] }, newest first
    @schedule =
      Price
        .order(starts_at: :desc)
        .pluck(:name, :starts_at, :value)
        .group_by(&:first)
        .transform_values { |rows| rows.map { [it[1], it[2]] } }
  end

  # Price per kWh of the given name on the given date, or nil before the
  # first price
  def at(name, date)
    @schedule.fetch(name.to_s, []).find { |starts_on, _| starts_on <= date }&.last&.to_f
  end
end

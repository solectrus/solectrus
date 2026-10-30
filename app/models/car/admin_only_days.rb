# The days of the car page that only the admin sees: today and yesterday. A
# day shows when the cars drove and charged, so a recent day tells when
# someone is away from home. An older day is public, so a visitor without
# the admin login, like on the demo, sees the same page some days back.
# The live view stays public, because it shows no time of a drive.
module Car::AdminOnlyDays
  COUNT = 2
  public_constant :COUNT

  # Whether the timeframe is such a day
  def self.cover?(timeframe) = timeframe.day? && timeframe.date > last_public_date

  # Whether the timeframe holds such a day, like the list of the sessions of
  # this week
  def self.overlap?(timeframe) = timeframe.all? || timeframe.ending >= beginning

  # The timeframe whose data a visitor sees: the same period, with its data up
  # to the latest public day (see Timeframe#max_date)
  def self.public_timeframe(timeframe) = Timeframe.new(timeframe.original_string, max_date: last_public_date)

  # The latest day that a visitor sees
  def self.last_public_date = Date.current - COUNT

  # The start of the first such day
  def self.beginning = last_public_date.next_day.beginning_of_day
end

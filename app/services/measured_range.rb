# How long the system has been measuring: the first day with data and the
# number of days from there up to a given day. Everything that reasons about
# the age of the measured data asks this - the savings series and its
# snapshots, and the amortization page, which needs the age alone and must not
# run a whole calculation for it.
class MeasuredRange
  def self.current(today: Date.current)
    new(today:)
  end

  # installation_date is given only when a past state is examined (a snapshot
  # of an earlier day); otherwise it is derived from the configuration and the
  # measured data.
  def initialize(today:, installation_date: nil)
    @today = today
    @installation_date = installation_date
  end

  attr_reader :today

  # Guard against the silent INSTALLATION_DATE fallback (2020-01-01):
  # clamp to the first day with measured data.
  def installation_date
    @installation_date ||=
      [
        Rails.configuration.x.installation_date,
        SummaryValue.minimum(:date),
      ].compact.max
  end

  # Inclusive: the installation day itself counts as the first measured day.
  def days
    @days ||= (today - installation_date).to_i + 1
  end

  # A full year of data captures seasonality; less than that makes every
  # projection from it uncertain. The measured year is the 365 days before
  # today, so it is complete only once the data reaches back that far - a
  # calendar year would still leave the first day of the window uncovered in
  # a year without a leap day.
  def full_year?
    installation_date <= today - 365.days
  end
end

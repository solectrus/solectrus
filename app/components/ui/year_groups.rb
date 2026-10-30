# The rows of a list in groups of a calendar year, by the date of each row
# (`date`). Each group starts with a header (see Ui::GroupHeader::Component),
# which names the year.
#
# `previous_date` is the date of the last row of the page before, so a group
# that goes on from there gets no second header.
class Ui::YearGroups
  include Enumerable

  def initialize(rows, previous_date: nil)
    @rows = rows
    @previous_date = previous_date
  end

  # Each row with the year that it starts, or with nil for a row that
  # continues the year of the row before
  def each(&) = @rows.zip(starts).each(&)

  private

  def starts
    [@previous_date, *@rows.map(&:date)]
      .map { it&.year }
      .each_cons(2)
      .map { |before, year| year unless year == before }
  end
end

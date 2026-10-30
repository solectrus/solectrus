# A list of amounts with their total: a grid on the desktop and a grouped
# list on a phone. The rows need no column headers, as each value tells what
# it is, like a date, a category pill or an amount. The total stands below
# the rows, in a group of its own on a phone. The block gives the rows, each
# a Ui::TableRow that spans the grid.
class Ui::AmountTable::Component < ViewComponent::Base
  # `grid_columns` is the template of the grid, one track for each column.
  # `unit` is the currency of the total.
  def initialize(grid_columns:, total:, unit:)
    super()
    @grid_columns = grid_columns
    @total = total
    @unit = unit
  end

  attr_reader :grid_columns

  def formatted_total = number_to_currency(@total, precision: 2, unit: @unit)

  def total_color = @total.negative? ? 'text-signal-negative' : 'text-signal-positive'
end

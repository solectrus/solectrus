# A list of amounts with their total: a grid on the desktop, whose header
# sticks to the top while the list scrolls, and a grouped list on a phone.
# The total stands below the rows, in a group of its own on a phone. The
# block gives the rows, each a Ui::TableRow that spans the grid. The last
# header is the column of the amount, so it stands at the right.
class Ui::AmountTable::Component < ViewComponent::Base
  # `grid_columns` is the template of the grid, one track for each header.
  # `unit` is the currency of the total.
  def initialize(headers:, grid_columns:, total:, unit:)
    super()
    @headers = headers
    @grid_columns = grid_columns
    @total = total
    @unit = unit
  end

  attr_reader :headers, :grid_columns

  def header_classes(index) = class_names('p-2', 'text-right' => index == headers.size - 1)

  def formatted_total = number_to_currency(@total, precision: 2, unit: @unit)

  def total_color = @total.negative? ? 'text-signal-negative' : 'text-signal-positive'
end

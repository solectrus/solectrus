# The prices of one name: a table on the desktop, whose rows open the form in
# the modal, and a grouped list on a phone, whose rows open the
# form on a page of its own (see Ui::TableRow::Component).
class Price::List::Component < ViewComponent::Base
  def initialize(prices:, name:)
    super()
    @prices = prices
    @name = name
  end

  attr_reader :prices, :name

  # Only the electricity tariff can carry a base fee, so only it needs the
  # column. Price enforces the same rule.
  def base_fee_column?
    name.to_s == 'electricity'
  end

  # The per-kWh column means the opposite thing in the two tables: what a kWh
  # drawn costs, or what a kWh fed in pays. The form labels already separate
  # the two, so the header does as well. It also has to tell the reader which
  # of the two electricity columns it is.
  def amount_label
    t("activerecord.attributes.price.amounts_per_kwh.#{name}")
  end

  def grid_columns
    base_fee_column? ? 'grid-cols-[auto_1fr_auto_auto_auto]' : 'grid-cols-[auto_1fr_auto_auto]'
  end
end

# The filter of the list of the cash flows (see CashFlow and ListFilter):
# some categories and a range of dates. A link of the amortization table and
# the chevrons of the rows set it.
CashFlow::Filter = Data.define(:categories, :from, :to) do
  include ListFilter

  def self.category_keys = CashFlow.categories.keys

  # The category of a new cash flow. The amortization table filters a whole
  # group of categories at once, so it is the first one of the filter.
  def category = categories.first
end

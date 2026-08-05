# Contents of the detail frame: the calculation, or the reason there is none to
# show yet. Rendered by the page shell when the result is already at hand and by
# the content action otherwise, so both paths show exactly the same thing.
class AmortizationDetail::Component < ViewComponent::Base
  def initialize(page:, view:)
    super()
    @page = page
    @view = view
  end

  attr_reader :page, :view

  delegate :timeframe, :missing_or_stale_days, :result, to: :page

  # Measured savings incomplete - the missing daily summaries have to be built
  # first (same mechanism as Top10), so the calculation runs on complete data.
  def summaries_incomplete? = missing_or_stale_days.present?
end

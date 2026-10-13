# One visit of the list. A phone wraps the cells into two lines of their own
# width: the place and the duration, then the town and the times.
class VisitList::Row::Component < ViewComponent::Base
  include VisitTexts

  def initialize(visit:, context:)
    super()
    @visit = visit
    @context = context
  end

  attr_reader :visit, :context
end

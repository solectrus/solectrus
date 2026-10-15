# The visits of the cars at the places, the latest first, each visit in one
# row. The list loads its pages one after the other (see Ui::LazyRows).
class Place::VisitList::Component < ViewComponent::Base
  def initialize(visits:, pagy:, context:)
    super()
    @visits = visits
    @pagy = pagy
    @context = context
  end

  attr_reader :visits, :pagy, :context
end

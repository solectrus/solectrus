class VisitList::NameCell::Component < ViewComponent::Base
  def initialize(place:)
    super()
    @place = place
  end

  attr_reader :place
end

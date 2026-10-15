# A filter of the list as a chip, with a link that removes it. The content
# names the filter.
class Place::VisitList::FilterChip::Component < ViewComponent::Base
  def initialize(remove_path:)
    super()
    @remove_path = remove_path
  end

  attr_reader :remove_path
end

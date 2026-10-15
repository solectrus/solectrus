class Top10::SortToggle::Component < ViewComponent::Base
  def desc?
    helpers.sort.desc?
  end
end

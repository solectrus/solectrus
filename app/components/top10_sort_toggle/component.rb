class Top10SortToggle::Component < ViewComponent::Base
  def desc?
    helpers.sort.desc?
  end
end

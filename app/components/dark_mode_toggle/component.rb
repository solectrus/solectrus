class DarkModeToggle::Component < ViewComponent::Base
  def available?
    ApplicationPolicy.dark_mode?
  end
end

# The offer of the sponsoring page: what the money buys.
#
# Ten features in one sentence are not read, so they are a list.
class SponsoringBenefits::Component < ViewComponent::Base
  # The locale file carries the names and their order, and nothing else here
  # depends on the single name. So this asks for the whole list at once, and a
  # name added to the locale file appears on the page without a change here.
  def benefits
    t('.benefits').values
  end
end

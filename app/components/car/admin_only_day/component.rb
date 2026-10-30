# Shown to a visitor in place of a day that only the admin sees (see
# Car::AdminOnlyDays): why the day is hidden, and the login
class Car::AdminOnlyDay::Component < ViewComponent::Base
  def login_path = helpers.new_session_path(return_to: helpers.request.fullpath)
end

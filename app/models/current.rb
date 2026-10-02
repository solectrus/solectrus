# Values that hold for one request (or one job) alone, and that the next one
# must not see. Rails resets them between requests.
class Current < ActiveSupport::CurrentAttributes
  # The names of the cars, see Car.names. A page asks for the display name of
  # each sensor it shows, so the request reads them one time.
  attribute :car_names
end

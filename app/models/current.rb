# Values that hold for one request (or one job) alone, and that the next one
# must not see. Rails resets them between requests.
class Current < ActiveSupport::CurrentAttributes
  # The names of the cars, see Car.names. A page asks for the display name of
  # each sensor it shows, so the request reads them one time.
  attribute :car_names

  # A guest sees the cars by their number, without their names (see
  # ApplicationController). The MCP server and the jobs see the names.
  attribute :car_names_hidden

  # The configured cars, see Car.configured. The page, its charts and the
  # summaries ask for them more than once in one request.
  attribute :cars
end

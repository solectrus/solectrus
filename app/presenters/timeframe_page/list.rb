# The addresses of a list with a timeframe, like the charging sessions or the
# visits. `route` is the route helper of the list, and `params` are the
# parameters that each link of the list keeps, like the car filter, which the
# address has in front. See TimeframePage::Sensor for the methods.
class TimeframePage::List
  include Rails.application.routes.url_helpers

  def initialize(route:, params:, hours:)
    @route = route
    @params = params
    @hours = hours
  end

  def path(timeframe)
    public_send(@route, timeframe:, **@params)
  end

  def base_url
    public_send(@route, **@params)
  end

  def label_for_all = I18n.t('timeframe.total')

  def forecast? = false

  def hours? = @hours
end

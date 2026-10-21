# The addresses of a list with a timeframe, like the charging sessions or the
# visits. `route` is the route helper of the list, and `params` are the
# parameters that each link of the list keeps, like the car filter, which the
# address has in front, or the map, which it has behind. See
# TimeframePage::Sensor for the methods.
class TimeframePage::List
  include Rails.application.routes.url_helpers

  # `kinds` are the kinds of timeframes that the list offers (see
  # Timeframe::Select::Component::KINDS)
  def initialize(route:, params:, kinds: Timeframe::Select::Component::KINDS)
    @route = route
    @params = params
    @kinds = kinds
  end

  def path(timeframe)
    public_send(@route, timeframe:, **@params)
  end

  def url_template = path(':timeframe')

  def label_for_all = I18n.t('timeframe.total')

  def forecast? = false

  def offers?(kind) = @kinds.include?(kind)
end

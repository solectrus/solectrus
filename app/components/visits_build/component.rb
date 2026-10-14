# The build of the days that wait for the visits (see PlaceVisitsBuild), in
# place of the content that needs them. The page loads again when it is done.
#
#   = render VisitsBuild::Component.new(timeframe:, pending_days: @pending_days) do
#     = render PlaceList::Component.new(places: @places, pagy: @pagy)
class VisitsBuild::Component < ViewComponent::Base
  def initialize(timeframe:, pending_days:)
    super()
    @timeframe = timeframe
    @pending_days = pending_days
  end

  def call
    return content if @pending_days.blank?

    render SummaryBuilder::Component.new(timeframe: @timeframe, missing_or_stale_days: @pending_days)
  end
end

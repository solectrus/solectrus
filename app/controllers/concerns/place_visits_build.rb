# The lists of the places and of the visits build the days that wait for the
# visits first, like the car page (see SummaryBuilder::Component). The visits
# give the time of each place, and the build makes the new places, so both
# lists are at most a few minutes old.
module PlaceVisitsBuild
  extend ActiveSupport::Concern

  included do
    helper_method :build_timeframe
  end

  private

  # The days to build: the whole time, unless a list shows less. The name is
  # not `timeframe`, which the layout reads for its links.
  def build_timeframe = Timeframe.new('all')

  def pending_visit_days
    return [] unless Place::VisitDetection.enabled?

    Summary.missing_or_stale_days_for(build_timeframe, steps: [Place::VisitDetection::KEY])
  end
end

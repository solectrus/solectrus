# The trends of a home page at a glance (TrendOverview), the first page of
# the sheet of the insights. A row leads one level down to the insights of
# its sensor (InsightsController). The page that holds the frame decides
# which sensors the overview shows, as for the insights. Without the
# permission, the sheet holds a teaser in place of the overview.
class TrendsController < ApplicationController
  include RefererNamespace

  # A request without the frame, like a link opened in a tab of its own,
  # and a period without trends go back to the page they came from
  def index
    unless turbo_frame_request? && TrendOverview.page_period?(page:, timeframe:)
      return redirect_back_or_to(root_path)
    end
    return render(:teaser) unless ApplicationPolicy.trends?

    @overview = TrendOverview.build(page:, timeframe:, base:, car: params[:car])
  end

  private

  # A visitor of the car page sees its data up to the latest public day,
  # like its charts (see Car::AdminOnlyDays)
  helper_method def timeframe
    @timeframe ||= begin
      frame = Timeframe.new(params[:timeframe])
      page == :cars && !admin? ? Car::AdminOnlyDays.public_timeframe(frame) : frame
    end
  end

  def page
    @page ||= referer_namespace.to_sym
  end

  # The route of the page that holds the frame, with its chart and its
  # period, which the demo of the teaser opens. Nil without a page of the
  # app, and the teaser then has no demo.
  helper_method def referer_route
    path = URI.parse(request.referer.to_s).path
    Rails.application.routes.recognize_path(path).slice(:controller, :action, :sensor_name, :timeframe, :car) if path.present?
  rescue URI::InvalidURIError, ActionController::RoutingError
    nil
  end

  # The earlier period, the year before unless the parameter asks for the
  # month before
  def base
    @base ||= TrendOverview.base_for(timeframe, params[:base])
  end
end

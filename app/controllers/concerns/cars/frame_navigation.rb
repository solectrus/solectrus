# The frames of the car page each load with the chart of their own column,
# but the links of the navigation keep the chart of the address. So only the
# frame of that chart renders the navigation (see cars/_navigation_streams),
# and the frames of the other column leave it alone. Without the check, the
# answer that came last decided the chart of each link.
#
# The address of the page comes as the referer: a pick of a chart puts its
# address into the history before its frame loads (see
# stats_with_chart/component_controller.ts). A browser does not always send a
# referer, and each frame then renders the navigation, as before.
module Cars::FrameNavigation
  extend ActiveSupport::Concern

  included do
    private

    helper_method def navigation_frame?
      address = referer_params
      address.nil? || address[:sensor_name].to_s == params[:sensor_name].to_s
    end
  end

  private

  def referer_params
    return if request.referer.blank?

    Rails.application.routes.recognize_path(URI.parse(request.referer).path)
  rescue URI::InvalidURIError, ActionController::RoutingError
    nil
  end
end

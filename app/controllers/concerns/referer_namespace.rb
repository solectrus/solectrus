# Extracts the controller namespace from the HTTP referer.
# Shared between TimeframeSelectController and InsightsController,
# which both need to know which section the user navigated from
# (as opposed to ApplicationHelper#controller_namespace which uses
# the current controller path).
module RefererNamespace
  NAMESPACE_SEGMENTS = %w[house inverter heatpump cars].freeze
  private_constant :NAMESPACE_SEGMENTS

  private

  def referer_namespace
    referer_path = URI.parse(request.referer.to_s).path
    NAMESPACE_SEGMENTS.find do |segment|
      referer_path.start_with?("/#{segment}/") || referer_path == "/#{segment}"
    end || 'balance'
  rescue URI::InvalidURIError
    'balance'
  end
end

if Rails.configuration.x.rorvswild.api_key
  RorVsWild.start(
    api_key: Rails.configuration.x.rorvswild.api_key,
    ignored_exceptions: %w[ActionController::RoutingError ForbiddenError],
  )
end

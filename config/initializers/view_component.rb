# Icons are rendered by a helper, and a ViewComponent does not see the helpers of
# the app unless they are mixed in. Reaching for `helpers.icon` in every template
# would work, but icons appear in dozens of them, and a component that renders
# itself outside the Rails render pipeline has no `helpers` at all.
Rails.application.config.to_prepare { ViewComponent::Base.include(IconHelper) }

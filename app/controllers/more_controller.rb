# The page behind the tab More of a phone: the secondary items, which do not
# fit into the tab bar, and the items of the menu as a grouped list. The
# desktop has these items in its top bar and never links here.
#
# A view among the secondary items stays a view: it shows no title bar, and
# it opens in the timeframe of the last view. Each other page in the list is
# a page below this one, which leads back here with a title bar (see the
# layout).
#
# The charging sessions are not in the list: they are a page below the car
# page.
class MoreController < ApplicationController
  def show
  end

  private

  helper_method def title
    t('layout.more')
  end

  # The timeframe of the last view, which the links to the views take over.
  # The links of the tab bar on this page take it too.
  def computed_timeframe
    return @computed_timeframe if defined?(@computed_timeframe)

    @computed_timeframe = remembered_timeframe
  end

  def remembered_timeframe
    Timeframe.new(session[:view_timeframe]) if session[:view_timeframe].present?
  rescue ArgumentError
    nil
  end

  # This page names no sensor of the power balance, so the balance opens on
  # its default sensor, in the timeframe of the last view. Without a sensor,
  # the path has no place for the timeframe, so it goes into the query, and
  # the balance takes it along when it sends the visit to its default sensor.
  def root_item
    return super unless computed_timeframe

    super.merge(href: balance_home_path(params: { timeframe: computed_timeframe.to_param }))
  end

  # A page below this one slides in, as it shows a title bar. It keeps its
  # own background. A view opens as it is.
  helper_method def secondary_links
    secondary_items.map { it[:view] ? it : it.merge(slide: true, plain: true) }
  end

  # A guest sees the settings too, and their page asks to log in. Only the
  # overview of the admin has a title bar that leads back here, so only it
  # slides.
  helper_method def system_items
    [
      settings_item.merge(href: settings_path, slide: admin?),
      helios_item,
      notifications_item&.merge(slide: true, plain: true),
    ].compact
  end

  # The registration leaves the app for the site of the registration
  helper_method def solectrus_items
    [registration_item&.merge(external: true), about_item].compact
  end

  helper_method def session_link
    session_item.merge(destructive: admin?)
  end

  # The keys of a menu item that a cell of the grouped list takes
  helper_method def cell_args(item)
    item.slice(:name, :icon, :href, :data, :badge_count, :dot, :slide, :plain, :external, :destructive)
  end
end

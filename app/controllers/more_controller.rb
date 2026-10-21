# The page behind the tab More of a phone: the secondary items, which do not
# fit into the tab bar, and the items of the menu as a grouped list. The
# desktop has these items in its top bar and never links here.
#
# A view among the secondary items stays a view: it shows no title bar. The
# other secondary items show a title bar without a way back, as they stand on
# their own like a tab. The pages below this one, like the notifications, lead
# back here with a title bar (see the layout).
class MoreController < ApplicationController
  def show
  end

  private

  helper_method def title
    t('layout.more')
  end

  # The pages of the cars that the page More lists, as in the menu of the
  # desktop (see MainNavigation#car_pages)
  helper_method def car_links
    car_pages.filter_map { it[:item].merge(plain: true, **it[:more]) if it[:more] }
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

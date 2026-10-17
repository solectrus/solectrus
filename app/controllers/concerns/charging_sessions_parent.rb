# On a phone, the charging sessions are a page below the page More when they
# opened from there, and else a page below the car page. The session keeps
# the parent across the kinds, the filter, the timeframe and the forms of the
# list. The car page forgets it (see Cars::HomeController).
module ChargingSessionsParent
  extend ActiveSupport::Concern

  KEY = :charging_sessions_below_more
  private_constant :KEY

  included do
    before_action :remember_parent
    helper_method :title_bar_back
  end

  def self.forget(session) = session.delete(KEY)

  private

  # Only the link of the page More carries the parameter
  def remember_parent
    session[KEY] = true if params[:from] == 'more'
  end

  # The tab More marks the list, not the tab of the car (see MainNavigation)
  def charging_sessions_below_more? = session[KEY] == true

  # The way back of the title bar. The page More has a title bar, so the way
  # back to it slides. The car page has none, so it does not.
  def title_bar_back
    if charging_sessions_below_more?
      { back_href: more_path, back_label: t('layout.more'), back_logo: more_logo }
    else
      { back_href: back_path, back_label: t('layout.car'), back_slide: false }
    end
  end
end

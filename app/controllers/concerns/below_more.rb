# On a phone, a page like the charging sessions is a page below the page More
# when it opened from there, and else a page below the car page. The session
# names the page that opened from the page More, and keeps it across the
# timeframe, the car and the other parameters of the page, and across the
# forms of the charging sessions. The car page forgets it (see
# Cars::HomeController).
module BelowMore
  extend ActiveSupport::Concern

  KEY = :below_more
  private_constant :KEY

  included do
    before_action :remember_parent
    helper_method :title_bar_back
  end

  def self.forget(session) = session.delete(KEY)

  private

  # Only the link of the page More carries the parameter
  def remember_parent
    session[KEY] = controller_name if params[:from] == 'more'
  end

  # The tab More marks the page, not the tab of the car (see MainNavigation)
  def below_more? = session[KEY] == controller_name

  # The way back of the title bar. The page More has a title bar, so the way
  # back to it slides. The car page has none, so it does not.
  def title_bar_back
    if below_more?
      { back_href: more_path, back_label: t('layout.more'), back_logo: more_logo }
    else
      { back_href: back_path, back_label: t('layout.car'), back_slide: false }
    end
  end
end

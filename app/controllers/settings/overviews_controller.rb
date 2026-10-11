# The entry page of the settings on a phone: a list of the settings sections,
# each opening its own page. Desktop reaches the sections through the tabs in
# the top bar and links straight to the first one.
class Settings::OverviewsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def show
  end

  private

  helper_method def title
    t('layout.settings')
  end
end

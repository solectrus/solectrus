# The page of the tariffs on a phone: a list of the two prices, each opening
# its own page. The desktop reaches the prices through the tabs at the side
# and links straight to the first one (see SettingsNavigation).
class Settings::TariffsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def show
  end

  private

  helper_method def title
    t('settings.tariffs.name')
  end
end

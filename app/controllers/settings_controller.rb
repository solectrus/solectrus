class SettingsController < ApplicationController
  before_action :admin_required!, except: %i[show]

  def show
  end

  def update
    permitted_params.each_key do |key|
      unless permitted_params[key].nil?
        Setting.public_send("#{key}=", permitted_params[key].strip)
      end
    end

    head :no_content
  end

  private

  def permitted_params
    params.require(:setting).permit(:plant_name, :operator_name)
  end

  helper_method def nav_items
    [
      { name: t('settings.general.name'), href: settings_path, current: true },
      {
        name: Price.human_enum_name(:name, :electricity),
        href: prices_path(name: 'electricity'),
        current: false,
      },
      {
        name: Price.human_enum_name(:name, :feed_in),
        href: prices_path(name: 'feed_in'),
        current: false,
      },
    ]
  end
end

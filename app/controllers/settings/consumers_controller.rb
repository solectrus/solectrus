class Settings::ConsumersController < ApplicationController
  before_action :admin_required!

  def edit
  end

  def update
    permitted_params.each_key do |key|
      unless permitted_params[key].nil?
        Setting.public_send(:"#{key}=", permitted_params[key].strip)
      end
    end

    respond_with_flash notice: t('crud.success')
  end

  private

  helper_method def title
    t('layout.settings')
  end

  def permitted_params
    params.require(:setting).permit(
      *(1..SensorConfig::CUSTOM_SENSOR_COUNT).map do |i|
        format('custom_name_%02d', i).to_sym
      end,
    )
  end

  helper_method def nav_items
    [
      {
        name: t('settings.general.name'),
        href: settings_general_path,
        current: false,
      },
      {
        name: Price.human_enum_name(:name, :electricity),
        href: settings_prices_path(name: 'electricity'),
        current: false,
      },
      {
        name: Price.human_enum_name(:name, :feed_in),
        href: settings_prices_path(name: 'feed_in'),
        current: false,
      },
      {
        name: t('settings.consumers.name'),
        href: settings_consumers_path,
        current: true,
      },
    ]
  end
end

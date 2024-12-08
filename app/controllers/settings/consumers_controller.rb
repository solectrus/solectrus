class Settings::ConsumersController < ApplicationController
  include SettingsNavigation

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
end

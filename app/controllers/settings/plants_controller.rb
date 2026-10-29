# The data of the PV system: its name and its operator. The first page of the
# PV system, beside its cash flows (see SettingsNavigation).
class Settings::PlantsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def edit
  end

  def update
    permitted_params.each do |key, value|
      Setting.public_send(:"#{key}=", value.strip) unless value.nil?
    end

    redirect_to edit_settings_plant_path, notice: t('crud.success')
  end

  private

  helper_method def title
    t('settings.plant.data')
  end

  def permitted_params
    params.expect(setting: %i[plant_name operator_name])
  end
end

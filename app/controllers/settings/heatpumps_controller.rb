# The heating that the heat pump compares with (see Heatpump::Heating). The
# page shows only with the heat pump page and the comparison (see
# SettingsNavigation#heatpump_settings?).
class Settings::HeatpumpsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!
  before_action :heatpump_settings_required!

  def edit
    @heating = Heatpump::Heating.current
  end

  def update
    @heating = Heatpump::Heating.current
    @heating.assign_attributes(permitted_params)

    if @heating.save
      redirect_to edit_settings_heatpump_path, notice: t('crud.success')
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  helper_method def title
    t('settings.heatpump.name')
  end

  def permitted_params
    params.expect(heatpump_heating: %i[fuel_type efficiency fixed_costs])
  end
end

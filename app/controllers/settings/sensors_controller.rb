class Settings::SensorsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def edit
    @battery_sensors = %i[battery_charging_power battery_discharging_power case_temp battery_soc car_battery_soc]
    @consumer_sensors = %i[house_power heatpump_power wallbox_power] + SensorConfig::CUSTOM_SENSORS
  end

  def update
    Setting.sensor_names = permitted_params.to_h.symbolize_keys

    respond_with_flash notice: t('crud.success')
  end

  private

  helper_method def title
    t('layout.settings')
  end

  def permitted_params
    params.expect(sensor_names: Array(SensorConfig.x.editable_sensor_names))
  end
end

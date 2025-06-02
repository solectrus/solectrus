class Settings::SensorsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def edit
    @battery_sensors = %i[
      battery_charging_power
      battery_discharging_power
      case_temp
      battery_soc
      car_battery_soc
    ]
    @consumer_sensors =
      %i[house_power heatpump_power wallbox_power] +
        SensorConfig::CUSTOM_SENSORS
  end

  def update
    Setting.sensor_names = permitted_params[:sensor_names]&.to_h

    %i[
      inverter_as_total
      enable_multi_inverter
      enable_custom_consumer
    ].each do |key|
      value = permitted_params.dig(:general, key)
      next unless value

      Setting.public_send("#{key}=", value == '1')
    end

    redirect_to settings_sensors_path, notice: t('crud.success')
  end

  private

  helper_method def title
    t('layout.settings')
  end

  def permitted_params
    params.except(:button, :_method).permit(
      sensor_names: Array(SensorConfig.x.editable_sensor_names),
      general: %i[
        inverter_as_total
        enable_multi_inverter
        enable_custom_consumer
      ],
    )
  end
end

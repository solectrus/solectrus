class Settings::SensorsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!

  def edit
    @inverter_sensors = []
    @consumer_sensors = []
    @battery_sensors = []

    Sensor::Config
      .nameable_sensors
      .sort_by { |sensor| [sensor.category, sensor.name] }
      .select do |sensor|
        case sensor.category
        when :inverter
          @inverter_sensors << sensor
        when :consumer
          @consumer_sensors << sensor
        else
          if sensor.name.in?(
               %i[
                 battery_charging_power
                 battery_discharging_power
                 case_temp
                 battery_soc
                 car_battery_soc
               ],
             )
            @battery_sensors << sensor
          end
        end
      end
  end

  def update
    Setting.sensor_names = permitted_params[:sensor_names]&.to_h

    %i[
      inverter_as_total
      enable_multi_inverter
      enable_custom_consumer
      enable_heatpump
      enable_forecast
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
    params.except(:button, :_method, :authenticity_token).permit(
      sensor_names: Array(Sensor::Config.nameable_sensors).map(&:name),
      general: %i[
        inverter_as_total
        enable_multi_inverter
        enable_custom_consumer
        enable_heatpump
        enable_forecast
      ],
    )
  end
end

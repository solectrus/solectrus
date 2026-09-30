class Settings::SensorsController < ApplicationController
  include SettingsNavigation

  before_action :admin_required!
  before_action :load_sensors, only: %i[edit section]

  # Desktop: every group in one form, as tabs. Phone: a list of the groups.
  def edit
  end

  # Phone: the form of one group
  def section
    @section = sensor_sections.find { |item| item[:id] == params[:section] }
    redirect_to settings_sensors_path unless @section
  end

  def update
    # A form of one group sends the names of its own sensors only
    if (names = permitted_params[:sensor_names]&.to_h)
      Setting.sensor_names = Setting.sensor_names.merge(names)
    end

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

    redirect_back_or_to settings_sensors_path, notice: t('crud.success')
  end

  private

  def load_sensors
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

  helper_method def sensor_sections
    @sensor_sections ||= [
      { id: 'generators', icon: 'solar-panel' },
      ({ id: 'consumers', icon: 'plug' } if @consumer_sensors.any?),
      ({ id: 'battery', icon: 'battery-half' } if @battery_sensors.any?),
    ].compact.map do |section|
      section.merge(
        name: t("settings.sensors.#{section[:id]}"),
        href: section_settings_sensors_path(section[:id]),
      )
    end
  end

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

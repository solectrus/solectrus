# @label Balance
class BalanceComponentPreview < ViewComponent::Preview
  def default
    render Balance::Component.new timeframe: Timeframe.day, calculator:, sensor:
  end

  def with_peak
    render Balance::Component.new timeframe: Timeframe.now,
                                  calculator:,
                                  sensor:,
                                  peak:
  end

  private

  CalculatorStruct =
    Struct.new(
      :time,
      #
      :inverter_power,
      :inverter_power_1,
      :inverter_power_2,
      :inverter_power_3,
      :grid_import_power,
      :grid_export_power,
      :battery_charging_power,
      :battery_discharging_power,
      :wallbox_power,
      :heatpump_power,
      :house_power,
      #
      :paid,
      :got,
      :battery_charging_costs,
      :wallbox_costs,
      :heatpump_costs,
      :house_costs,
    ) do
      def total_plus
        @total_plus ||=
          grid_import_power.to_f + battery_discharging_power.to_f +
            inverter_power.to_f
      end

      def total_minus
        @total_minus ||=
          grid_export_power.to_f + battery_charging_power.to_f +
            house_power.to_f + excluded_custom_sensor_names_total.to_f +
            heatpump_power.to_f + wallbox_power.to_f
      end

      ###

      %i[
        inverter_power
        grid_import_power
        battery_discharging_power
      ].each do |name|
        define_method("#{name}_percent") do
          public_send(name).to_f * 100.0 / total_plus
        end
      end

      %i[
        grid_export_power
        battery_charging_power
        house_power
        heatpump_power
        wallbox_power
      ].each do |name|
        define_method("#{name}_percent") do
          public_send(name).to_f * 100.0 / total_minus
        end
      end

      ##

      def valid_multi_inverter?
        false
      end

      def excluded_custom_sensor_names_total
      end
    end
  private_constant :CalculatorStruct

  def calculator
    @calculator ||=
      CalculatorStruct.new(
        inverter_power: 900,
        grid_import_power: 1000,
        battery_discharging_power: 300,
        #
        grid_export_power: 150,
        battery_charging_power: 200,
        house_power: 500,
        heatpump_power: 50,
        wallbox_power: 1300,
        #
        paid: 0,
      )
  end

  def sensor
    :inverter_power
  end

  def peak
    # All at maximum power
    {
      inverter_power: 900,
      grid_import_power: 1000,
      battery_discharging_power: 300,
      #
      grid_export_power: 150,
      battery_charging_power: 200,
      house_power: 500,
      heatpump_power: 50,
      wallbox_power: 1300,
    }
  end
end

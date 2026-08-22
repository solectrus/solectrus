class Sensor::Definitions::InverterPowerTotal < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'

  depends_on do
    (1..Sensor::Definitions::CustomInverterPower::MAX).filter_map do |number|
      sensor_name = :"inverter_power_#{number}"
      sensor_name if Sensor::Config.configured?(sensor_name)
    end
  end

  # An inverter without a reading in this bucket makes the TOTAL unknown, not
  # smaller: summing the rest looks measured, so a missed sample renders as a
  # drop to the remaining inverter rather than as a gap the charts can bridge.
  #
  # That holds only for an inverter that REPORTS at this moment. One the user
  # added later, or removed, or whose collector stood still for the whole
  # timeframe, delivers nothing here. It must not veto the others.
  #
  # +sensor_names_with_data+ tells the two apart (see Sensor::Query::Base).
  # The configuration never does. Without that list (Sensor::SummaryBuilder) a
  # value is the only evidence there is.
  calculate do |sensor_names_with_data: nil, **kwargs|
    inverters = kwargs.select { |name, _| name.start_with?('inverter_power_') }

    powers =
      if sensor_names_with_data
        inverters.slice(*sensor_names_with_data).values
      else
        inverters.values.compact
      end

    return if powers.empty? || powers.any?(&:nil?)

    powers.sum
  end

  aggregations stored: false, computed: [:sum]
end

module Sensor
  module Query
    # The prices of a fuel in InfluxDB (see FuelPrices). The prices of the
    # fuels of a car and of heating oil come once a week, in EUR per liter.
    # The price of natural gas comes once a month, in EUR per kWh. They are no
    # sensor: the measurements and the fields are fixed, so they need no
    # configuration.
    class FuelPrices
      # { fuel type => "MEASUREMENT:field" }, like a sensor
      FIELDS = {
        'petrol' => 'Fuel:price_petrol',
        'diesel' => 'Fuel:price_diesel',
        'lpg' => 'Fuel:price_lpg',
        'heating_oil' => 'Fuel:price_heating_oil',
        'gas' => 'Gas:price',
      }.freeze
      private_constant :FIELDS

      def initialize(fuel_type)
        @measurement, @field = FIELDS[fuel_type.to_s]&.split(':')
      end

      # [[date, price], ...] of all time, sorted by date. An unknown fuel has
      # none.
      def call
        return [] unless field

        Helpers::Influx::FluxProgram
          .query(flux, class_name: self.class.name, sensors: [])
          .map { [Time.zone.parse(it['_time']).to_date, it['_value'].to_f] }
          .sort_by(&:first)
      end

      private

      attr_reader :measurement, :field

      def flux
        <<~FLUX
          from(bucket: "#{Helpers::Influx::FluxProgram.bucket}")
            |> range(start: 0)
            |> filter(fn: (r) => r._measurement == "#{measurement}" and r._field == "#{field}")
            |> keep(columns: ["_time", "_value"])
        FLUX
      end
    end
  end
end

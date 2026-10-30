module Sensor
  module Query
    # The weekly prices of a fuel (EUR per liter) in InfluxDB (see
    # Car::FuelPrices). They are no sensor: the measurement and the fields
    # are fixed, so they need no configuration.
    class FuelPrices
      MEASUREMENT = 'Fuel'.freeze
      private_constant :MEASUREMENT

      FIELDS = { 'petrol' => 'price_petrol', 'diesel' => 'price_diesel' }.freeze
      private_constant :FIELDS

      def initialize(fuel_type)
        @field = FIELDS[fuel_type.to_s]
      end

      # [[date, price], ...] of all time, sorted by date
      def call
        Helpers::Influx::FluxProgram
          .query(flux, class_name: self.class.name, sensors: [])
          .map { [Time.zone.parse(it['_time']).to_date, it['_value'].to_f] }
          .sort_by(&:first)
      end

      private

      attr_reader :field

      def flux
        <<~FLUX
          from(bucket: "#{Helpers::Influx::FluxProgram.bucket}")
            |> range(start: 0)
            |> filter(fn: (r) => r._measurement == "#{MEASUREMENT}" and r._field == "#{field}")
            |> keep(columns: ["_time", "_value"])
        FLUX
      end
    end
  end
end

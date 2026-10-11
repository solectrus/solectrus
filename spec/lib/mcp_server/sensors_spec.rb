describe McpServer::Sensors do
  describe '.all' do
    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
          'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
        ),
      )
    end

    after { Sensor::Config.setup(ENV) }

    it 'leaves out the personal sensors' do
      expect(Sensor::Config.sensors.map(&:name)).to include(:car_latitude_1, :car_longitude_1)
      expect(described_class.all.map(&:name)).not_to include(:car_latitude_1, :car_longitude_1, :car_location)
    end

    it 'keeps the other sensors' do
      expect(described_class.all.map(&:name)).to include(:car_battery_soc_1)
    end
  end
end

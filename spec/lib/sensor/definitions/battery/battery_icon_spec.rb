describe 'Battery sensor icons' do # rubocop:disable RSpec/DescribeClass
  %i[battery_power battery_charging_power battery_discharging_power].each do |sensor_name|
    describe sensor_name.to_s do
      subject(:sensor) { Sensor::Registry[sensor_name] }

      def icon_for(soc)
        sensor.icon(data: Struct.new(:battery_soc).new(soc))
      end

      it 'shows the state of charge' do
        expect(icon_for(5)).to eq('battery-empty')
        expect(icon_for(20)).to eq('battery-quarter')
        expect(icon_for(45)).to eq('battery-half')
        expect(icon_for(70)).to eq('battery-three-quarters')
        expect(icon_for(95)).to eq('battery-full')
      end

      it 'shows a half battery without a state of charge' do
        expect(sensor.icon(data: Object.new)).to eq('battery-half')
        expect(icon_for(nil)).to eq('battery-half')
      end
    end
  end
end

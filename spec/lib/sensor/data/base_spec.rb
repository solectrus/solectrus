class DataTest < Sensor::Data::Base
  def sensor_names
    %i[inverter_power battery_soc wallbox_car_connected case_temp system_status]
  end

  def get_sensor_value(sensor_name, _args)
    convert_value(raw_data[sensor_name], sensor_name)
  end
end

describe Sensor::Data::Base do
  subject(:data) { DataTest.new(raw_data, timeframe:) }

  let(:timeframe) { Timeframe.day }
  let(:raw_data) do
    {
      inverter_power: '1000',
      battery_soc: '85.5',
      wallbox_car_connected: '1',
      case_temp: '25.3',
      system_status: 'foo',
    }
  end

  describe 'initialization' do
    it 'accepts Hash as raw_data' do
      expect { data }.not_to raise_error
    end
  end

  describe 'accessors' do
    it 'creates accessors for each sensor' do
      expect(data.inverter_power).to eq(1000)
      expect(data.battery_soc).to eq(85.5)
      expect(data.wallbox_car_connected).to be(true)
      expect(data.case_temp).to eq(25.3)

      expect(data.timeframe).to eq(timeframe)
    end
  end

  describe 'type conversion' do
    let(:raw_data) do
      {
        inverter_power: '4200', # watt unit
        battery_soc: '85.5', # percent unit
        wallbox_car_connected: false, # boolean unit
        case_temp: '25.3', # celsius unit
        system_status: 'online', # string unit
      }
    end

    it 'converts watt values to float' do
      expect(data.inverter_power).to eq(4200.0)
    end

    it 'converts percent values to float' do
      expect(data.battery_soc).to eq(85.5)
    end

    it 'converts boolean values correctly' do
      expect(data.wallbox_car_connected).to be(false)
    end

    it 'converts celsius values to float' do
      expect(data.case_temp).to eq(25.3)
    end

    it 'converts string values to string' do
      expect(data.system_status).to eq('online')
    end

    it 'preserves nil values' do
      nil_data = DataTest.new({ inverter_power: nil }, timeframe:)
      expect(nil_data.inverter_power).to be_nil
    end
  end

  describe 'validation' do
    it 'rejects invalid timeframe types' do
      expect { DataTest.new({}, timeframe: 'invalid') }.to raise_error(
        ArgumentError,
        'timeframe must be a Timeframe, got String',
      )
    end
  end
end

describe Sensor::Query::InterpolatedValue do
  subject(:result) { described_class.new(:car_mileage_1, target_time).call }

  before do
    stub_const('ENV', ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_1' => 'Trabant:mileage'))
    stub_feature(:car)
  end

  let(:measurement) { Sensor::Config.measurement(:car_mileage_1) }
  let(:field) { Sensor::Config.field(:car_mileage_1) }

  def add_mileage(time:, value:)
    add_influx_point(name: measurement, fields: { field => value.to_f }, time:)
  end

  describe '#call' do
    context 'with a point before and after the target time' do
      # 10:00 -> 1000, 14:00 -> 1200 ; target 12:00 -> halfway -> 1100.
      let(:target_time) { Time.zone.local(2024, 3, 10, 12, 0, 0) }

      before do
        add_mileage(time: Time.zone.local(2024, 3, 10, 10, 0, 0), value: 1000)
        add_mileage(time: Time.zone.local(2024, 3, 10, 14, 0, 0), value: 1200)
      end

      it 'linearly interpolates between the surrounding points' do
        expect(result).to be_within(0.001).of(1100.0)
      end
    end

    context 'with asymmetric surrounding points' do
      # 08:00 -> 500, 20:00 -> 620 ; target 11:00 -> 3/12 -> 500 + 30 = 530.
      let(:target_time) { Time.zone.local(2024, 3, 10, 11, 0, 0) }

      before do
        add_mileage(time: Time.zone.local(2024, 3, 10, 8, 0, 0), value: 500)
        add_mileage(time: Time.zone.local(2024, 3, 10, 20, 0, 0), value: 620)
      end

      it 'weights the interpolation by elapsed time' do
        expect(result).to be_within(0.001).of(530.0)
      end
    end

    context 'with a reading exactly at the target time' do
      let(:target_time) { Time.zone.local(2024, 3, 10, 12, 0, 0) }

      before do
        add_mileage(time: Time.zone.local(2024, 3, 10, 10, 0, 0), value: 1000)
        add_mileage(time: target_time, value: 1234)
        add_mileage(time: Time.zone.local(2024, 3, 10, 14, 0, 0), value: 9999)
      end

      it 'returns that exact value without interpolating' do
        expect(result).to eq(1234.0)
      end
    end

    context 'with only a point before the target time' do
      let(:target_time) { Time.zone.local(2024, 3, 10, 12, 0, 0) }

      before { add_mileage(time: Time.zone.local(2024, 3, 9, 8, 0, 0), value: 777) }

      it 'falls back to the last known value' do
        expect(result).to eq(777.0)
      end
    end

    context 'with only a point after the target time' do
      let(:target_time) { Time.zone.local(2024, 3, 10, 12, 0, 0) }

      before { add_mileage(time: Time.zone.local(2024, 3, 11, 8, 0, 0), value: 888) }

      it 'uses the first known value as the start anchor (monotonic assumption)' do
        expect(result).to eq(888.0)
      end
    end

    context 'with no data at all' do
      let(:target_time) { Time.zone.local(2024, 3, 10, 12, 0, 0) }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when the target time precedes the installation date' do
      let(:target_time) do
        Rails.configuration.x.installation_date.beginning_of_day - 1.day
      end

      before do
        add_mileage(time: Time.zone.local(2024, 3, 10, 10, 0, 0), value: 1000)
      end

      it 'returns nil without querying' do
        expect(result).to be_nil
      end
    end

    context 'when the sensor is not configured' do
      subject(:result) { described_class.new(:car_mileage_1, target_time).call }

      let(:target_time) { Time.zone.local(2024, 3, 10, 12, 0, 0) }

      before { stub_const('ENV', ENV.to_h.merge('INFLUX_SENSOR_CAR_MILEAGE_1' => '')) }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end

  describe 'caching' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

    before do
      travel_to Time.zone.local(2024, 3, 11, 12, 0, 0)
      allow(Rails).to receive(:cache).and_return(memory_store)
      allow(Influx).to receive(:query).and_call_original
    end

    it 'caches a past midnight' do
      2.times { described_class.new(:car_mileage_1, Time.zone.local(2024, 3, 11)).call }

      expect(Influx).to have_received(:query).once
    end

    it 'does not cache the running day' do
      2.times { described_class.new(:car_mileage_1, Time.current).call }

      expect(Influx).to have_received(:query).twice
    end
  end
end

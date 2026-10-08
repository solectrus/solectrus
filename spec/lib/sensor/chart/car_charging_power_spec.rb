describe Sensor::Chart::CarChargingPower do
  subject(:chart) { described_class.new(timeframe:, cars:) }

  let(:car) { Car.create!(id: 1, active_from: Date.new(2026, 1, 1)) }
  let(:other_car) { Car.create!(id: 2, active_from: Date.new(2026, 1, 1)) }
  let(:cars) { [car] }
  let(:timeframe) { Timeframe.new('2026-06-15') }

  def offsite(car, from, to, kwh)
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: from, ended_at: to, kwh:, cost: 4)
  end

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  def offsite_data
    chart.data[:datasets].find { it[:id] == 'offsite' }&.dig(:data)
  end

  def value_at(time)
    offsite_data[chart.data[:labels].index(time.to_i * 1000)]
  end

  before { travel_to Time.zone.local(2026, 9, 23, 12) }

  context 'without an offsite session' do
    it 'draws the wallbox alone, without a stacked axis' do
      expect(chart.data[:datasets].filter_map { it[:id] }).to eq(%w[wallbox_power])
      expect(chart.options.dig(:scales, :y, :stacked)).to be_nil
    end
  end

  context 'with an offsite session from 12:00 to 13:00' do
    before { offsite(car, at(12), at(13), 11) }

    it 'stacks a rectangle of its mean power on the wallbox' do
      expect(chart.options.dig(:scales, :y, :stacked)).to be(true)
      expect(chart.data[:datasets].filter_map { it[:id] }).to eq(%w[wallbox_power offsite])
      expect(chart.data[:datasets].last).to include(fill: '-1', colorClass: 'bg-sensor-offsite', label: 'Offsite charging')

      # A label is the end of its 5-minute bucket
      expect([value_at(at(12)), value_at(at(12, 5)), value_at(at(13)), value_at(at(13, 5))]).to eq([0, 11_000, 11_000, 0])
    end

    it 'gives the wallbox a 0 W baseline when InfluxDB has no data' do
      wallbox = chart.data[:datasets].first[:data]

      expect(wallbox.size).to eq(288)
      expect(wallbox).to all(eq(0))
    end
  end

  context 'with a session shorter than a bucket' do
    before { offsite(car, at(12, 1), at(12, 3), 1) }

    it 'keeps its energy in the bucket' do
      expect(value_at(at(12, 5))).to eq(12_000)
    end
  end

  context 'with a session without an end' do
    before { offsite(car, at(9), nil, 24) }

    it 'spreads its energy over the whole day' do
      expect(offsite_data).to all(eq(1_000))
    end
  end

  context 'with the power splitter' do
    before do
      stub_feature(:power_splitter)
      influx_batch do
        { wallbox_power: 7_000, wallbox_power_pv: 3_000, wallbox_power_grid: 4_000 }.each do |sensor_name, watt|
          add_influx_point(name: Sensor::Config.measurement(sensor_name), fields: { Sensor::Config.field(sensor_name) => watt }, time: at(12, 2))
        end
      end
    end

    it 'stacks PV and grid instead of the wallbox' do
      expect(chart.data[:datasets].filter_map { it[:id] }).to eq(%w[wallbox_power_pv wallbox_power_grid])
      expect(chart.data[:datasets].last).to include(fill: '-1', colorClass: Car::ChargingSource[:grid].color_class)
      expect(chart.options.dig(:scales, :y, :stacked)).to be(true)
    end

    context 'with the live view' do
      let(:timeframe) { Timeframe.now }

      it 'draws the wallbox' do
        expect(chart.data[:datasets].filter_map { it[:id] }).to eq(%w[wallbox_power])
      end
    end
  end

  context 'with the power splitter, but without its data' do
    before { stub_feature(:power_splitter) }

    it 'draws the wallbox' do
      expect(chart.data[:datasets].filter_map { it[:id] }).to eq(%w[wallbox_power])
      expect(chart.options.dig(:scales, :y, :stacked)).to be_nil
    end
  end

  context 'with the session of another car' do
    before { offsite(other_car, at(12), at(13), 11) }

    it 'leaves it out' do
      expect(offsite_data).to be_nil
    end
  end

  context 'with the live view' do
    let(:timeframe) { Timeframe.now }

    before { offsite(car, 1.hour.ago, Time.current, 11) }

    it 'draws no offsite session' do
      expect(chart.options.dig(:scales, :y, :stacked)).to be_nil
    end
  end
end

describe Sensor::Query::Helpers::Influx::DailyStates do
  subject(:call) { described_class.new(dates, [:car_battery_soc_1]).call }

  before do
    stub_const('ENV', ENV.to_h.merge('INFLUX_SENSOR_CAR_BATTERY_SOC_1' => 'Trabant:soc'))
    stub_feature(:car)

    measurement = Sensor::Config.measurement(:car_battery_soc_1)
    field = Sensor::Config.field(:car_battery_soc_1)

    influx_batch do
      readings.each do |time, value|
        add_influx_point(name: measurement, fields: { field => value.to_f }, time:)
      end
    end
  end

  def values(date) = call.dig(date, :car_battery_soc_1)

  # A car that drives in the morning of March 9 and then stands still
  let(:readings) do
    [
      [Time.zone.local(2024, 3, 7, 18), 80],
      [Time.zone.local(2024, 3, 9, 6), 60],
      [Time.zone.local(2024, 3, 9, 18), 40],
    ]
  end

  let(:dates) { [Date.new(2024, 3, 8), Date.new(2024, 3, 9), Date.new(2024, 3, 10)] }

  it 'holds the last reading before a day without a reading' do
    expect(values(Date.new(2024, 3, 8))).to eq(min: 80, max: 80, avg: 80)
    expect(values(Date.new(2024, 3, 10))).to eq(min: 40, max: 40, avg: 40)
  end

  # 6 hours at 80, 12 hours at 60 and 6 hours at 40
  it 'weights each value with its time' do
    expect(values(Date.new(2024, 3, 9))).to eq(min: 40, max: 80, avg: 60)
  end

  context 'with a day before the first reading' do
    let(:dates) { [Date.new(2024, 3, 6), Date.new(2024, 3, 7)] }

    it 'gives no values' do
      expect(values(Date.new(2024, 3, 6))).to eq(min: nil, max: nil, avg: nil)
    end

    # From 18:00 on
    it 'starts the day with the first reading' do
      expect(values(Date.new(2024, 3, 7))).to eq(min: 80, max: 80, avg: 80)
    end
  end

  context 'with the running day' do
    let(:dates) { [Date.new(2024, 3, 9)] }

    before { travel_to Time.zone.local(2024, 3, 9, 12) }

    # 6 hours at 80 and 6 hours at 60, without the hours after now
    it 'ends now' do
      expect(values(Date.new(2024, 3, 9))).to eq(min: 60, max: 80, avg: 70)
    end
  end
end

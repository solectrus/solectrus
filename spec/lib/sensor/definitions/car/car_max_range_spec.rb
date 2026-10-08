describe Sensor::Definitions::CarMaxRange do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { Sensor::Registry[:car_max_range_1] }

  describe '#dependencies' do
    it 'reads the live values' do
      expect(sensor.dependencies).to eq(%i[car_range_1 car_battery_soc_1])
    end

    it 'reads only its own stored field in SQL' do
      expect(sensor.dependencies(context: :sql)).to eq(%i[car_max_range_1])
    end

    it 'exposes the live values as static dependencies' do
      expect(sensor.static_dependencies).to eq(%i[car_range_1 car_battery_soc_1])
    end
  end

  describe 'summary' do
    let(:date) { Date.yesterday }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge('INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range'),
      )

      influx_batch do
        [[8, 200, 50], [20, 300, 100]].each do |hour, range, soc|
          time = date.beginning_of_day + hour.hours

          add_influx_point(name: 'Trabant', fields: { 'range' => range.to_f }, time:)
          add_influx_point(
            name: Sensor::Config.measurement(:car_battery_soc_1),
            fields: { Sensor::Config.field(:car_battery_soc_1) => soc.to_f },
            time:,
          )
        end
      end
    end

    # 250 km at 75 %
    it 'calculates the daily average from the stored averages' do
      data = Sensor::SummaryBuilder.new(Timeframe.new(date.iso8601)).call

      expect(data.car_range_1(:avg)).to eq(250)
      expect(data.car_max_range_1(:avg)).to be_within(0.01).of(333.33)
    end
  end

  describe '#calculate' do
    it 'extrapolates the range to a full battery' do
      expect(sensor.calculate(car_range_1: 200, car_battery_soc_1: 50)).to eq(400)
    end

    it 'prefers the stored value' do
      expect(
        sensor.calculate(car_max_range_1: 380, car_range_1: 200, car_battery_soc_1: 50),
      ).to eq(380)
    end

    it 'answers nil without a charge' do
      expect(sensor.calculate(car_range_1: 200, car_battery_soc_1: 0)).to be_nil
    end
  end

  describe 'SQL integration' do
    subject(:result) { query.call.car_max_range_1(:avg, :avg) }

    let(:query) do
      Sensor::Query::Helpers::Sql::Total.new(timeframe) do |q|
        q.avg :car_max_range_1, :avg
        q.group_by :day
      end
    end

    let(:first_date) { Rails.configuration.x.installation_date }
    let(:timeframe) { Timeframe.new("#{first_date}..#{first_date + 1.day}") }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge('INFLUX_SENSOR_CAR_RANGE_1' => 'Trabant:range'),
      )

      create_summary(date: first_date, values: [[:car_max_range_1, :avg, 410]])
      create_summary(
        date: first_date + 1.day,
        values: [[:car_max_range_1, :avg, 405]],
      )
    end

    it 'returns the stored daily average' do
      expect(result[first_date]).to eq(410)
      expect(result[first_date + 1.day]).to eq(405)
    end
  end
end

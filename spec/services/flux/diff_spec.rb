describe Flux::Diff do
  subject(:aggregation) { described_class.new(sensors:) }

  let(:sensors) { [:car_mileage] }
  let(:date) { Date.new(2024, 10, 1) }

  before do
    # Three full days with 90 km difference
    influx_batch do
      add_influx_point name: measurement_car_mileage,
                       fields: {
                         field_car_mileage => 100.0,
                       },
                       time: (date - 1.day).beginning_of_day

      add_influx_point name: measurement_car_mileage,
                       fields: {
                         field_car_mileage => 190.0,
                       },
                       time: (date + 1.day).end_of_day
    end
  end

  describe '#call' do
    subject(:call) { aggregation.call(timeframe:) }

    let(:timeframe) { Timeframe.new(date.iso8601) }

    it { is_expected.to eq({ diff_car_mileage: 30 }) }
  end
end

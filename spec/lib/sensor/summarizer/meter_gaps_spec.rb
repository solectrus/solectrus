describe Sensor::Summarizer::MeterGaps do
  subject(:gaps) { described_class.new(dates, diffs) }

  let(:diffs) { Sensor::Query::Helpers::Influx::DailyDiffs.new(dates, sensor_names) }

  let(:sensor_names) { [:car_odometer_1] }
  let(:dates) { [thursday] }

  # The car reports on Monday at 18:00 and then not until Thursday at 10:00
  let(:readings) do
    [
      [monday.beginning_of_day + 18.hours, 1000],
      [thursday.beginning_of_day + 10.hours, 1300],
    ]
  end

  def monday = Date.new(2024, 3, 4)
  def thursday = Date.new(2024, 3, 7)
  def gap_days = [monday, monday + 1, monday + 2]

  before do
    stub_const('ENV', ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:mileage'))
    stub_feature(:car)

    influx_batch do
      readings.each do |time, value|
        add_influx_point(name: 'Trabant', fields: { 'mileage' => value.to_f }, time:)
      end
    end
  end

  def build_summaries(updated_at)
    gap_days.each { Summary.create!(date: it, updated_at:) }
  end

  context 'when the days of the gap were built during the gap' do
    before { build_summaries(thursday.beginning_of_day + 2.hours) }

    it 'finds them' do
      expect(gaps.stale_dates([thursday])).to match_array(gap_days)
    end

    it 'leaves out the days that the chunk builds' do
      expect(gaps.stale_dates([thursday, monday + 2])).to contain_exactly(monday, monday + 1)
    end
  end

  context 'when the days of the gap were built after the gap' do
    before { build_summaries(thursday.beginning_of_day + 11.hours) }

    it 'finds nothing' do
      expect(gaps.stale_dates([thursday])).to be_empty
    end
  end

  # A car that stood still gives no build
  context 'when the meter did not change' do
    let(:readings) do
      [
        [monday.beginning_of_day + 18.hours, 1000],
        [thursday.beginning_of_day + 10.hours, 1000],
      ]
    end

    before { build_summaries(thursday.beginning_of_day + 2.hours) }

    it 'finds nothing' do
      expect(gaps.stale_dates([thursday])).to be_empty
    end
  end

  # The offline car sends a 0 on Wednesday, which is no reading of the meter
  context 'with a wrong reading during the gap' do
    let(:readings) do
      [
        [monday.beginning_of_day + 18.hours, 1000],
        [(monday + 2).beginning_of_day + 12.hours, 0],
        [thursday.beginning_of_day + 10.hours, 1300],
      ]
    end

    before { build_summaries(thursday.beginning_of_day + 2.hours) }

    it 'finds the days from the last right reading' do
      expect(gaps.stale_dates([thursday])).to match_array(gap_days)
    end
  end

  context 'without a reading after the gap' do
    let(:readings) { [[monday.beginning_of_day + 18.hours, 1000]] }

    before { build_summaries(thursday.beginning_of_day + 2.hours) }

    it 'finds nothing' do
      expect(gaps.stale_dates([thursday])).to be_empty
    end
  end

  # The day before the run saw each reading up to now
  context 'when the same build built the day before the run' do
    subject(:gaps) { described_class.new(dates, diffs, built: Set[thursday - 1]) }

    before { build_summaries(thursday.beginning_of_day + 2.hours) }

    it 'asks InfluxDB nothing' do
      allow(Influx).to receive(:query)

      expect(gaps.stale_dates([thursday])).to be_empty
      expect(Influx).not_to have_received(:query)
    end
  end

  context 'without a meter' do
      let(:sensor_names) { [] }

      it 'asks InfluxDB nothing' do
        allow(Influx).to receive(:query)

        expect(gaps.stale_dates([thursday])).to be_empty
        expect(Influx).not_to have_received(:query)
      end
  end
end

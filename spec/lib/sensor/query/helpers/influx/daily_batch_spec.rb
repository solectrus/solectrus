describe Sensor::Query::Helpers::Influx::DailyBatch do
  subject(:batch) do
    described_class.new(
      dates,
      sum_sensor_names: Sensor::SummaryBuilder.sum_sensor_names,
      aggregation_sensor_names:
        Sensor::SummaryBuilder.aggregation_sensor_names,
    )
  end

  let(:seeded_dates) { [2.days.ago.to_date, 1.day.ago.to_date, Date.current] }
  let(:dates) { seeded_dates }

  before do
    stub_feature(:heatpump)

    influx_batch do
      seeded_dates.each_with_index do |date, day|
        (0..5).each do |slot|
          time = date.beginning_of_day + (slot * 4).hours

          add_influx_point(
            name: Sensor::Config.measurement(:inverter_power_1),
            fields: {
              Sensor::Config.field(:inverter_power_1) =>
                (day * 500) + 2000 + (slot * 100),
            },
            time:,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:house_power),
            fields: {
              Sensor::Config.field(:house_power) => (day * 100) + 2500 + (slot * 50),
            },
            time:,
          )

          add_influx_point(
            name: Sensor::Config.measurement(:case_temp),
            fields: {
              Sensor::Config.field(:case_temp) => day + 20 + slot,
            },
            time:,
          )
        end
      end
    end
  end

  describe '#call' do
    subject(:call) { batch.call }

    it 'answers for every requested day' do
      expect(call.keys).to eq(dates)
    end

    # The whole point of batching: fewer requests, identical numbers
    it 'returns the same values as querying each day on its own' do
      dates.each do |date|
        timeframe = Timeframe.new(date.iso8601)

        batched = Sensor::SummaryBuilder.new(timeframe, prefetched: call[date]).call
        separate = Sensor::SummaryBuilder.new(timeframe).call

        expect(batched.raw_data).to eq(separate.raw_data), "differs for #{date}"
      end
    end

    it 'keeps the days apart' do
      first = call[dates.first][:sum].inverter_power_1
      last = call[dates.last][:sum].inverter_power_1

      expect(first).to be_positive
      expect(last).to be > first
    end

    context 'with a single day' do
      let(:dates) { [Date.current] }

      # Flux has no union of one table, so this takes a different code path
      it 'works without a union' do
        expect(call[dates.first][:sum].inverter_power_1).to be_positive
      end
    end

    context 'when a day has no data at all' do
      let(:dates) { [Date.current, 400.days.ago.to_date] }

      it 'returns nil values for it' do
        expect(call[400.days.ago.to_date][:sum].inverter_power_1).to be_nil
      end
    end
  end

  describe 'caching' do
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

    before { allow(Rails).to receive(:cache).and_return(memory_store) }

    # A later single-day run has to find what the batch fetched, so the rows
    # are stored under the key that day's own query would use
    it 'stores each day under the key its own query uses' do
      batch.call

      dates.each do |date|
        query =
          Sensor::Query::Helpers::Influx::Integral.new(
            Sensor::SummaryBuilder.sum_sensor_names,
            Timeframe.new(date.iso8601),
          )

        expect(query.cached_rows).to be_present, "nothing cached for #{date}"
      end
    end

    it 'takes cached days out of the Flux program' do
      batch.call

      allow(Influx).to receive(:query).and_call_original
      described_class
        .new(
          dates,
          sum_sensor_names: Sensor::SummaryBuilder.sum_sensor_names,
          aggregation_sensor_names:
            Sensor::SummaryBuilder.aggregation_sensor_names,
        )
        .call

      expect(Influx).not_to have_received(:query)
    end
  end
end

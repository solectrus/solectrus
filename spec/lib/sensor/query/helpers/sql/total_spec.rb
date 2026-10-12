describe Sensor::Query::Helpers::Sql::Total do
  let(:timeframe) { Timeframe.new('2025-01-15') }

  describe '#initialize' do
    it 'requires a block for DSL configuration' do
      expect { described_class.new(timeframe) }.to raise_error(
        ArgumentError,
        /Block required for DSL configuration/,
      )
    end

    it 'builds sensor requests from DSL' do
      query =
        described_class.new(timeframe) do |q|
          q.sum :inverter_power_1, :sum
          q.avg :outdoor_temp, :min
        end

      expect(query.sensor_requests).to include(%i[inverter_power_1 sum sum])
      expect(query.sensor_requests).to include(%i[outdoor_temp avg min])
    end

    it 'sets timeframe from parameter' do
      query =
        described_class.new(timeframe) { |q| q.sum :inverter_power_1, :sum }

      expect(query.timeframe).to eq(timeframe)
    end

    it 'sets group_by from DSL' do
      query =
        described_class.new(timeframe) do |q|
          q.sum :inverter_power_1, :sum
          q.group_by :month
        end

      expect(query.group_by).to eq(:month)
    end

    it 'defaults group_by to nil' do
      query =
        described_class.new(timeframe) { |q| q.sum :inverter_power_1, :sum }

      expect(query.group_by).to be_nil
    end
  end

  describe 'DSL methods' do
    it 'supports sum aggregation' do
      query = described_class.new(timeframe) { |q| q.sum :house_power, :sum }

      expect(query.sensor_requests).to include(%i[house_power sum sum])
    end

    it 'supports avg aggregation' do
      query = described_class.new(timeframe) { |q| q.avg :case_temp, :avg }

      expect(query.sensor_requests).to include(%i[case_temp avg avg])
    end

    it 'supports min aggregation' do
      query = described_class.new(timeframe) { |q| q.min :outdoor_temp, :min }

      expect(query.sensor_requests).to include(%i[outdoor_temp min min])
    end

    it 'supports max aggregation' do
      query = described_class.new(timeframe) { |q| q.max :outdoor_temp, :max }

      expect(query.sensor_requests).to include(%i[outdoor_temp max max])
    end

    it 'supports different meta and base aggregations' do
      query = described_class.new(timeframe) { |q| q.avg :outdoor_temp, :min }

      expect(query.sensor_requests).to include(%i[outdoor_temp avg min])
    end

    it 'handles multiple sensors' do
      query =
        described_class.new(timeframe) do |q|
          q.sum :house_power, :sum
          q.avg :outdoor_temp, :min
          q.max :outdoor_temp, :max
        end

      expect(query.sensor_requests).to include(%i[house_power sum sum])
      expect(query.sensor_requests).to include(%i[outdoor_temp avg min])
      expect(query.sensor_requests).to include(%i[outdoor_temp max max])
    end

    it 'supports simplified syntax without base aggregation' do
      query = described_class.new(timeframe) { |q| q.sum :house_power }

      expect(query.sensor_requests).to include(%i[house_power sum sum])
    end
  end

  describe '#call' do
    context 'without group_by' do
      it 'returns Sensor::Data::Single' do
        query =
          described_class.new(timeframe) { |q| q.sum :inverter_power_1, :sum }

        # Stub the fetch_raw_data method to avoid SQL execution
        allow(query).to receive(:fetch_raw_data).and_return({})

        result = query.call
        expect(result).to be_a(Sensor::Data::Single)
      end
    end

    context 'with group_by' do
      it 'returns Sensor::Data::Series' do
        query =
          described_class.new(timeframe) do |q|
            q.sum :inverter_power_1, :sum
            q.group_by :month
          end

        # Stub the fetch_raw_data method to avoid SQL execution
        allow(query).to receive(:fetch_raw_data).and_return({})

        result = query.call
        expect(result).to be_a(Sensor::Data::Series)
      end
    end
  end

  describe 'inheritance from base class' do
    it 'inherits sensor validation from base class' do
      query =
        described_class.new(timeframe) { |q| q.sum :inverter_power_1, :sum }

      # Sensor should be validated through base class mechanism
      expect(query.sensor_names).to include(:inverter_power_1)
    end

    it 'has access to timeframe from base class' do
      query =
        described_class.new(timeframe) { |q| q.sum :inverter_power_1, :sum }

      expect(query.timeframe).to eq(timeframe)
    end
  end

  describe 'sensor request processing' do
    it 'processes dependency resolution correctly' do
      query =
        described_class.new(timeframe) do |q|
          q.avg :autarky, :avg # Calculated sensor with dependencies
        end

      # Should include dependencies for calculated sensors
      expect(query.sensor_requests.length).to be > 1
      query.sensor_requests.each do |request|
        expect(request.length).to eq(3)
        expect(request.first).to be_a(Symbol)
        expect(request[1]).to be_a(Symbol)
        expect(request[2]).to be_a(Symbol)
      end
    end

    it 'handles calculated sensors correctly' do
      query =
        described_class.new(timeframe) do |q|
          q.sum :house_power, :sum # Calculated sensor
        end

      # Should process calculated sensors appropriately
      expect(query.sensor_requests).not_to be_empty
      expect(query.sensor_names).to include(:house_power)
    end

    context 'when querying calculated sensor with sql_calculation (savings)' do
      subject(:query) do
        described_class.new(timeframe) { |q| q.sum :savings, :sum }
      end

      let(:start_date) { Rails.configuration.x.installation_date }
      let(:end_date) { start_date + 1.month }
      let(:timeframe) { Timeframe.new("#{start_date}..#{end_date}") }
      let(:test_date) { start_date + 1.day }

      before do
        create_summary(
          date: test_date,
          values: [
            [:grid_import_power, :sum, 20_000],
            [:grid_export_power, :sum, 30_000],
            [:house_power, :sum, 30_000],
            [:heatpump_power, :sum, 10_000],
            [:wallbox_power, :sum, 5_000],
          ],
        )
      end

      it 'loads all required dependencies for Ruby calculation' do
        # Savings is a calculated sensor with sql_calculation method
        # It depends on traditional_costs and solar_price, which need Ruby calculation
        # So their dependencies must be loaded from SQL

        sensor_names = query.sensor_requests.map(&:first)

        # traditional_costs (FinanceBase) needs these base power sensors
        expect(sensor_names).to include(:house_power)
        expect(sensor_names).to include(:heatpump_power)
        expect(sensor_names).to include(:wallbox_power)

        # solar_price (calculated with sql_calculation) needs grid power
        expect(sensor_names).to include(:grid_import_power)
        expect(sensor_names).to include(:grid_export_power)

        # This test ensures that calculated sensors with sql_calculation
        # still load their dependencies when those dependencies need Ruby execution
      end

      it 'calculates the correct savings value' do
        result = query.call

        # With test data (all values in Wh):
        # house=30k, heatpump=10k, wallbox=5k, grid_import=20k, grid_export=30k
        # Prices: electricity=0.2545 EUR/kWh, feed_in=0.0832 EUR/kWh

        # traditional_costs = (30 + 10 + 5) * 0.2545 = 11.4525
        expect(result.traditional_costs).to be_within(0.0001).of(11.4525)

        # solar_price = 20*0.2545 - 30*0.0832 = 5.09 - 2.496 = 2.594
        expect(result.solar_price).to be_within(0.0001).of(2.594)

        # savings = 11.4525 - 2.594 = 8.8585
        expect(result.savings).to be_within(0.0001).of(8.8585)
      end

      context 'with a base fee' do
        subject(:query) do
          described_class.new(timeframe) do |q|
            q.sum :grid_energy_costs, :sum
            q.sum :grid_base_fee, :sum
            q.sum :grid_costs, :sum
            q.sum :traditional_costs, :sum
            q.sum :savings, :sum
          end
        end

        before do
          Price
            .find_by!(name: :electricity)
            .update!(amount_per_month: 30, starts_at: start_date)
        end

        # Only the single day that has a summary carries a share, and that
        # share is a 30th or 31st of the monthly amount.
        let(:daily_fee) { 30.0 / test_date.end_of_month.day }

        it 'adds the daily share to the grid costs' do
          expect(query.call.grid_costs).to be_within(0.0001).of(daily_fee + 5.09)
        end

        it 'adds the daily share to the traditional costs' do
          expect(query.call.traditional_costs).to be_within(0.0001).of(
            daily_fee + 11.4525,
          )
        end

        it 'leaves the savings untouched, because both sides carry it' do
          expect(query.call.savings).to be_within(0.0001).of(8.8585)
        end

        it 'reports the two halves on their own' do
          result = query.call

          expect(result.grid_energy_costs).to be_within(0.0001).of(5.09)
          expect(result.grid_base_fee).to be_within(0.0001).of(daily_fee)
        end

        # What the tooltip shows. All three come out of this one query, so the
        # breakdown adds up to the sum above it, to the cent.
        it 'adds the two halves up to the grid costs' do
          result = query.call

          expect(result.grid_energy_costs + result.grid_base_fee).to be_within(
            0.0001,
          ).of(result.grid_costs)
        end
      end
    end

    # The base fee does not grow with the consumption, so it is not split
    # across the consumers. The house carries all of it, which keeps the
    # per-consumer costs adding up to grid_costs.
    context 'when billing the base fee to the consumers' do
      subject(:query) do
        described_class.new(timeframe) do |q|
          q.sum :grid_costs, :sum
          q.sum :house_costs_grid, :sum
          q.sum :wallbox_costs_grid, :sum
        end
      end

      let(:start_date) { Rails.configuration.x.installation_date }
      let(:test_date) { start_date + 1.day }
      let(:timeframe) { Timeframe.new(test_date.to_s) }
      let(:daily_fee) { 30.0 / test_date.end_of_month.day }

      before do
        stub_feature(:power_splitter)

        Price
          .find_by!(name: :electricity)
          .update!(amount_per_month: 30, starts_at: start_date)

        create_summary(
          date: test_date,
          values: [
            [:grid_import_power, :sum, 20_000],
            [:house_power_grid, :sum, 15_000],
            [:wallbox_power_grid, :sum, 5_000],
          ],
        )
      end

      it 'bills the whole fee to the house, and none to the wallbox' do
        result = query.call

        expect(result.house_costs_grid).to be_within(0.0001).of(
          (15 * 0.2545) + daily_fee,
        )
        expect(result.wallbox_costs_grid).to be_within(0.0001).of(5 * 0.2545)
      end

      it 'lets the consumers add up to the grid costs' do
        result = query.call

        expect(
          result.house_costs_grid + result.wallbox_costs_grid,
        ).to be_within(0.0001).of(result.grid_costs)
      end

      context 'when the house has no grid share on that day' do
        before do
          create_summary(
            date: test_date + 1.day,
            values: [
              [:grid_import_power, :sum, 4_000],
              [:wallbox_power_grid, :sum, 4_000],
            ],
          )
        end

        let(:timeframe) do
          Timeframe.new("#{test_date}..#{test_date + 1.day}")
        end

        it 'still bills the fee of that day to the house' do
          result = query.call

          expect(result.house_costs_grid).to be_within(0.0001).of(
            (15 * 0.2545) + (daily_fee * 2),
          )
          expect(
            result.house_costs_grid + result.wallbox_costs_grid,
          ).to be_within(0.0001).of(result.grid_costs)
        end
      end
    end

    context 'when feed_in price is missing' do
      let(:test_date) { Rails.configuration.x.installation_date + 1.day }
      let(:timeframe) { Timeframe.new(test_date.to_s) }

      before do
        Price.find_by(name: :feed_in).destroy!

        create_summary(
          date: test_date,
          values: [
            [:grid_import_power, :sum, 10_000],
            [:grid_export_power, :sum, 5_000],
          ],
        )
      end

      it 'returns kWh values even without feed_in price' do
        query =
          described_class.new(timeframe) do |q|
            q.sum :grid_import_power
            q.sum :grid_export_power
            q.sum :grid_costs
            q.sum :grid_revenue
          end

        result = query.call

        expect(result.grid_import_power).to eq(10_000)
        expect(result.grid_export_power).to eq(5_000)
        expect(result.grid_costs).to be_present
        expect(result.grid_revenue).to be_nil
      end
    end

    # Regression: an open/current period (e.g. the bare current year) must be
    # clamped to today. Rows dated in the future part of the period would
    # otherwise leak into the totals and skew derived ratios.
    context 'with an open current-year timeframe' do
      before { travel_to Date.new(2026, 6, 21) }

      it 'ignores future-dated rows beyond today' do
        create_summary(
          date: '2026-03-15',
          values: [[:grid_export_power, :sum, 40_000]],
        )
        create_summary(
          date: '2026-09-15', # after today, still within the year
          values: [[:grid_export_power, :sum, 50_000]],
        )

        result =
          described_class.new(Timeframe.new('2026')) do |q|
            q.sum :grid_export_power
          end.call

        expect(result.grid_export_power).to eq(40_000)
      end
    end

    # inverter_power is calculated here (INFLUX_SENSOR_INVERTER_POWER is unset
    # in .env.test), so it is the sum of a roof and a balcony inverter. SQL
    # answers with a column per stored field, NULLs included, so a day before
    # the balcony inverter existed must not read as a day it missed.
    context 'with an inverter that only covers part of the timeframe' do
      subject(:query) do
        described_class.new(timeframe) do |q|
          q.sum :inverter_power, :sum
          q.group_by :day
        end
      end

      let(:first_date) { Rails.configuration.x.installation_date }
      let(:timeframe) { Timeframe.new("#{first_date}..#{first_date + 2.days}") }

      def roof_only(date, value)
        create_summary(date:, values: [[:inverter_power_1, :sum, value]])
      end

      def roof_and_balcony(date, roof:, balcony:)
        create_summary(
          date:,
          values: [
            [:inverter_power_1, :sum, roof],
            [:inverter_power_2, :sum, balcony],
          ],
        )
      end

      context 'when the balcony inverter is added on the last day' do
        before do
          roof_only(first_date, 30_000)
          roof_only(first_date + 1.day, 32_000)
          roof_and_balcony(first_date + 2.days, roof: 31_000, balcony: 2_000)
        end

        it 'keeps the earlier days at the roof inverter alone' do
          result = query.call.inverter_power(:sum, :sum)

          expect(result[first_date]).to eq(30_000)
          expect(result[first_date + 1.day]).to eq(32_000)
          expect(result[first_date + 2.days]).to eq(33_000)
        end
      end

      context 'when the summary stores a total of its own' do
        before do
          create_summary(
            date: first_date,
            values: [
              [:inverter_power, :sum, 99_000],
              [:inverter_power_1, :sum, 30_000],
              [:inverter_power_2, :sum, 2_000],
            ],
          )
          roof_only(first_date + 1.day, 31_000)
        end

        def ungrouped_total(date)
          described_class.new(Timeframe.new(date.to_s)) do |q|
            q.sum :inverter_power, :sum
          end.call.inverter_power
        end

        def ungrouped_over_both_days
          both_days = Timeframe.new("#{first_date}..#{first_date + 1.day}")

          described_class.new(both_days) do |q|
            q.sum :inverter_power, :sum
          end.call.inverter_power
        end

        it 'prefers that total, and falls back where the field is empty' do
          result = query.call.inverter_power(:sum, :sum)

          expect(result[first_date]).to eq(99_000)
          expect(result[first_date + 1.day]).to eq(31_000)
        end

        # An empty field used to end the lookup, so the second day answered
        # 31000 grouped and nil ungrouped.
        it 'answers the same ungrouped, with the field and without' do
          expect(ungrouped_total(first_date)).to eq(99_000)
          expect(ungrouped_total(first_date + 1.day)).to eq(31_000)
        end

        # SUM skips a row where the field is empty, so a total over both days
        # answered 99000 while the chart drew 99000 and 31000.
        it 'counts the day without the field in a total over both' do
          expect(ungrouped_over_both_days).to eq(99_000 + 31_000)
        end
      end

      context 'when the balcony inverter misses a day in between' do
        before do
          roof_and_balcony(first_date, roof: 30_000, balcony: 2_000)
          roof_only(first_date + 1.day, 32_000)
          roof_and_balcony(first_date + 2.days, roof: 31_000, balcony: 2_500)
        end

        it 'reports the gap instead of the roof inverter alone' do
          result = query.call.inverter_power(:sum, :sum)

          expect(result[first_date]).to eq(32_000)
          expect(result[first_date + 1.day]).to be_nil
          expect(result[first_date + 2.days]).to eq(33_500)
        end
      end
    end
  end
end

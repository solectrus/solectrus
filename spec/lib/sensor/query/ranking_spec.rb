describe Sensor::Query::Ranking do
  subject(:ranking) do
    described_class.new(sensor_name, desc:, period:, start:, stop:)
  end

  let(:sensor_name) { :heatpump_power }

  before do
    stub_feature(:heatpump)

    create_summary(
      date: '2024-01-15',
      values: [[:house_power, :sum, 25_000], [:heatpump_power, :sum, 15_000]],
    )

    create_summary(
      date: '2024-01-16',
      values: [[:house_power, :sum, 25_000], [:heatpump_power, :sum, 14_000]],
    )
  end

  describe '#call' do
    subject(:call) { ranking.call }

    let(:start) { Date.new(2024, 1, 1) }
    let(:stop) { Date.new(2024, 1, 31) }

    context 'when for days' do
      let(:period) { :day }

      context 'when descending' do
        let(:desc) { true }

        it 'returns the expected ranking' do
          expect(call).to eq(
            [
              { date: Date.new(2024, 1, 15), value: 15_000 },
              { date: Date.new(2024, 1, 16), value: 14_000 },
            ],
          )
        end
      end

      context 'when ascending' do
        let(:desc) { false }

        it 'returns the expected ranking' do
          expect(call).to eq(
            [
              { date: Date.new(2024, 1, 16), value: 14_000 },
              { date: Date.new(2024, 1, 15), value: 15_000 },
            ],
          )
        end

        context 'when stop date is today' do
          let(:stop) { Date.current }

          before do
            travel_to Date.new(2024, 1, 17)
            create_summary(
              date: Date.current,
              values: [[:heatpump_power, :sum, 1000]],
            )
          end

          it 'excludes today from ranking' do
            # Today has value 1000 which would be the minimum,
            # but it should be excluded because it's not complete yet
            expect(call).to eq(
              [
                { date: Date.new(2024, 1, 16), value: 14_000 },
                { date: Date.new(2024, 1, 15), value: 15_000 },
              ],
            )
          end
        end

        context 'when including installation day' do
          let(:start) { nil } # Let it default so installation_date logic applies
          let(:stop) { nil }

          before do
            # Set installation date to Jan 15
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2024, 1, 15))

            create_summary(
              date: Date.new(2024, 1, 15),
              values: [[:heatpump_power, :sum, 500]],
            )
          end

          it 'excludes the installation day from ranking' do
            # Jan 15 has value 500 which would be the minimum,
            # but it should be excluded because it may be incomplete
            expect(call).to eq([{ date: Date.new(2024, 1, 16), value: 14_000 }])
          end
        end

        context 'when explicit start includes installation day' do
          let(:start) { Date.new(2024, 1, 15) } # Explicit start
          let(:stop) { Date.new(2024, 1, 31) }

          before do
            # Set installation date to Jan 15
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2024, 1, 15))

            create_summary(
              date: Date.new(2024, 1, 15),
              values: [[:heatpump_power, :sum, 500]],
            )
          end

          it 'excludes the installation day from ranking even with explicit start' do
            # Jan 15 has value 500 which would be the minimum,
            # but should still be excluded (important for Insights::Extremum)
            expect(call).to eq([{ date: Date.new(2024, 1, 16), value: 14_000 }])
          end
        end
      end
    end

    context 'when for months' do
      let(:period) { :month }

      context 'when descending' do
        let(:desc) { true }

        it 'returns the expected ranking' do
          expect(call).to eq([{ date: Date.new(2024, 1, 1), value: 29_000 }])
        end
      end

      context 'when ascending' do
        let(:desc) { false }

        it 'returns the expected ranking' do
          expect(call).to eq([{ date: Date.new(2024, 1, 1), value: 29_000 }])
        end

        context 'when stop date is in current month' do
          let(:start) { nil }
          let(:stop) { nil }

          before do
            travel_to Date.new(2024, 2, 15)

            create_summary(
              date: Date.new(2024, 2, 10),
              values: [[:heatpump_power, :sum, 3000]],
            )
          end

          it 'excludes current month from ranking' do
            # February has only 3000 which would be minimum,
            # but it should be excluded because it's not complete yet
            expect(call).to eq([{ date: Date.new(2024, 1, 1), value: 29_000 }])
          end
        end

        context 'when installation date is in first month' do
          let(:start) { nil }
          let(:stop) { nil }

          before do
            # Installation on Jan 15
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2024, 1, 15))

            # Add data for February
            create_summary(
              date: Date.new(2024, 2, 10),
              values: [[:heatpump_power, :sum, 5000]],
            )
          end

          it 'excludes installation month from ranking' do
            # January has 29000 total but should be excluded
            # because installation was mid-month
            expect(call).to eq([{ date: Date.new(2024, 2, 1), value: 5000 }])
          end
        end

        context 'when no complete months exist' do
          let(:start) { nil }
          let(:stop) { nil }

          before do
            travel_to Date.new(2024, 2, 15) # Mid-February

            # Installation on January 15
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2024, 1, 15))

            # Data in January (incomplete, started mid-month)
            create_summary(
              date: Date.new(2024, 1, 20),
              values: [[:heatpump_power, :sum, 10_000]],
            )

            # Data in February (incomplete, current month)
            create_summary(
              date: Date.new(2024, 2, 10),
              values: [[:heatpump_power, :sum, 3000]],
            )
          end

          it 'returns empty array' do
            # January is incomplete (started mid-month)
            # February is incomplete (current month)
            # No complete months exist, so return empty array
            expect(call).to eq([])
          end
        end
      end
    end

    context 'when for weeks' do
      let(:period) { :week }
      let(:start) { Date.new(2024, 3, 1) } # Use March to avoid conflicts
      let(:stop) { Date.new(2024, 3, 31) }

      before do
        # Week starting March 4
        create_summary(
          date: Date.new(2024, 3, 6),
          values: [[:heatpump_power, :sum, 8000]],
        )
        # Week starting March 11
        create_summary(
          date: Date.new(2024, 3, 13),
          values: [[:heatpump_power, :sum, 12_000]],
        )
      end

      context 'when descending' do
        let(:desc) { true }

        it 'returns the expected ranking' do
          expect(call).to eq(
            [
              { date: Date.new(2024, 3, 11), value: 12_000 },
              { date: Date.new(2024, 3, 4), value: 8000 },
            ],
          )
        end
      end

      context 'when ascending' do
        let(:desc) { false }

        it 'returns the expected ranking' do
          expect(call).to eq(
            [
              { date: Date.new(2024, 3, 4), value: 8000 },
              { date: Date.new(2024, 3, 11), value: 12_000 },
            ],
          )
        end

        context 'when current week has data' do
          let(:start) { Date.new(2024, 3, 1) }
          let(:stop) { Date.current }

          before do
            travel_to Date.new(2024, 3, 20) # Wednesday of week starting March 18

            create_summary(
              date: Date.new(2024, 3, 19),
              values: [[:heatpump_power, :sum, 2000]],
            )
          end

          it 'excludes current week from ranking' do
            # Week starting March 18 has only 2000 which would be minimum,
            # but should be excluded
            expect(call).to eq(
              [
                { date: Date.new(2024, 3, 4), value: 8000 },
                { date: Date.new(2024, 3, 11), value: 12_000 },
              ],
            )
          end
        end

        context 'when installation week has data' do
          let(:start) { nil }
          let(:stop) { nil }

          before do
            travel_to Date.new(2024, 3, 25) # After all test weeks

            # Installation on March 6 (in week starting March 4)
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2024, 3, 6))
          end

          it 'excludes installation week from ranking' do
            # Week starting March 4 should be excluded
            expect(call).to eq([{ date: Date.new(2024, 3, 11), value: 12_000 }])
          end
        end

        context 'when no complete weeks exist' do
          let(:start) { nil }
          let(:stop) { nil }

          before do
            travel_to Date.new(2024, 3, 10) # Sunday of first week

            # Installation on March 4 (Monday of week starting March 4)
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2024, 3, 4))

            # Data in first week (incomplete, started Monday)
            create_summary(
              date: Date.new(2024, 3, 6),
              values: [[:heatpump_power, :sum, 8000]],
            )

            # Data in second week (incomplete, current week)
            create_summary(
              date: Date.new(2024, 3, 8),
              values: [[:heatpump_power, :sum, 5000]],
            )
          end

          it 'returns empty array' do
            # First week is incomplete (started mid-week)
            # Second week is incomplete (current week)
            # No complete weeks exist, so return empty array
            expect(call).to eq([])
          end
        end
      end
    end

    context 'when for years' do
      let(:period) { :year }
      let(:start) { Date.new(2021, 1, 1) } # Use different years
      let(:stop) { Date.new(2023, 12, 31) }

      before do
        create_summary(
          date: Date.new(2021, 6, 1),
          values: [[:heatpump_power, :sum, 50_000]],
        )
        create_summary(
          date: Date.new(2022, 6, 1),
          values: [[:heatpump_power, :sum, 60_000]],
        )
      end

      context 'when descending' do
        let(:desc) { true }

        it 'returns the expected ranking' do
          expect(call).to eq(
            [
              { date: Date.new(2022, 1, 1), value: 60_000 },
              { date: Date.new(2021, 1, 1), value: 50_000 },
            ],
          )
        end
      end

      context 'when ascending' do
        let(:desc) { false }

        it 'returns the expected ranking' do
          expect(call).to eq(
            [
              { date: Date.new(2021, 1, 1), value: 50_000 },
              { date: Date.new(2022, 1, 1), value: 60_000 },
            ],
          )
        end

        context 'when current year has data' do
          let(:start) { Date.new(2021, 1, 1) }
          let(:stop) { Date.current }

          before do
            travel_to Date.new(2023, 6, 15)

            create_summary(
              date: Date.new(2023, 3, 1),
              values: [[:heatpump_power, :sum, 30_000]],
            )
          end

          it 'excludes current year from ranking' do
            # 2023 has only 30000 which would be minimum,
            # but should be excluded
            expect(call).to eq(
              [
                { date: Date.new(2021, 1, 1), value: 50_000 },
                { date: Date.new(2022, 1, 1), value: 60_000 },
              ],
            )
          end
        end

        context 'when installation year has data' do
          let(:start) { nil }
          let(:stop) { nil }

          before do
            travel_to Date.new(2023, 1, 1) # After test years

            # Installation on June 1, 2021
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2021, 6, 1))
          end

          it 'excludes installation year from ranking' do
            # 2021 should be excluded
            expect(call).to eq([{ date: Date.new(2022, 1, 1), value: 60_000 }])
          end
        end

        context 'when no complete years exist' do
          let(:start) { nil }
          let(:stop) { nil }

          before do
            travel_to Date.new(2025, 10, 17) # October 2025

            # Installation in 2024
            allow(Rails.application.config.x).to receive(
              :installation_date,
            ).and_return(Date.new(2024, 6, 1))

            # Data in 2024 (incomplete year, started in June)
            create_summary(
              date: Date.new(2024, 6, 15),
              values: [[:heatpump_power, :sum, 40_000]],
            )

            # Data in 2025 (incomplete year, only until October)
            create_summary(
              date: Date.new(2025, 3, 1),
              values: [[:heatpump_power, :sum, 30_000]],
            )
          end

          it 'returns empty array' do
            # 2024 is incomplete (started mid-year)
            # 2025 is incomplete (current year)
            # No complete years exist, so return empty array
            expect(call).to eq([])
          end
        end
      end
    end

    context 'when using multi-field sensor (calculated)' do
      # Test for sensors that depend on multiple storable fields
      # In test environment, inverter_power is calculated from inverter_power_1 + inverter_power_2
      # This ensures the GROUP BY logic works correctly
      let(:sensor_name) { :inverter_power }
      let(:period) { :day }
      let(:desc) { true }
      let(:start) { Date.new(2024, 1, 1) }
      let(:stop) { Date.new(2024, 1, 31) }

      before do
        # inverter_power is always stored in summary (calculated from parts and stored)
        # Parts are also stored
        create_summary(
          date: '2024-01-15',
          values: [
            [:inverter_power, :sum, 15_000],
            [:inverter_power_1, :sum, 10_000],
            [:inverter_power_2, :sum, 5_000],
          ],
        )

        create_summary(
          date: '2024-01-16',
          values: [
            [:inverter_power, :sum, 12_000],
            [:inverter_power_1, :sum, 8_000],
            [:inverter_power_2, :sum, 4_000],
          ],
        )
      end

      it 'correctly aggregates multiple fields and returns ranking' do
        expect(call).to eq(
          [
            { date: Date.new(2024, 1, 15), value: 15_000 },
            { date: Date.new(2024, 1, 16), value: 12_000 },
          ],
        )
      end

      context 'when for weeks' do
        let(:period) { :week }
        let(:start) { Date.new(2024, 3, 1) }
        let(:stop) { Date.new(2024, 3, 31) }

        before do
          # Week starting March 4
          create_summary(
            date: Date.new(2024, 3, 6),
            values: [
              [:inverter_power, :sum, 7000],
              [:inverter_power_1, :sum, 5000],
              [:inverter_power_2, :sum, 2000],
            ],
          )
          create_summary(
            date: Date.new(2024, 3, 7),
            values: [
              [:inverter_power, :sum, 6000],
              [:inverter_power_1, :sum, 4000],
              [:inverter_power_2, :sum, 2000],
            ],
          )

          # Week starting March 11
          create_summary(
            date: Date.new(2024, 3, 13),
            values: [
              [:inverter_power, :sum, 11_000],
              [:inverter_power_1, :sum, 8000],
              [:inverter_power_2, :sum, 3000],
            ],
          )
        end

        it 'correctly aggregates multiple fields by week' do
          # Week of March 4: 7000 + 6000 = 13000
          # Week of March 11: 11000
          expect(call).to eq(
            [
              { date: Date.new(2024, 3, 4), value: 13_000 },
              { date: Date.new(2024, 3, 11), value: 11_000 },
            ],
          )
        end
      end
    end

    context 'when using sql-calculated sensor (finance)' do
      let(:sensor_name) { :grid_revenue }
      let(:period) { :day }
      let(:desc) { true }
      let(:start) { Rails.configuration.x.installation_date }
      let(:stop) { start + 1.month }

      before do
        # Create grid export data
        create_summary(
          date: start + 1.day,
          values: [[:grid_export_power, :sum, 25_000]], # 25 kWh * 0.0832 = 2.08 EUR
        )

        create_summary(
          date: start + 2.days,
          values: [[:grid_export_power, :sum, 30_000]], # 30 kWh * 0.0832 = 2.496 EUR
        )
      end

      it 'correctly calculates revenue and returns ranking' do
        expect(call).to eq(
          [
            { date: start + 2.days, value: 2.496 },
            { date: start + 1.day, value: 2.08 },
          ],
        )
      end

      context 'when for months' do
        let(:period) { :month }

        it 'correctly aggregates revenue by month' do
          result = call
          expect(result.size).to eq(1)
          expect(result[0][:date]).to eq(start.beginning_of_month)
          expect(result[0][:value]).to be_within(0.001).of(4.576)
        end
      end
    end

    context 'when using composite sensor calculated from sql sensors (total_costs)' do
      let(:sensor_name) { :total_costs }
      let(:period) { :day }
      let(:desc) { true }
      let(:start) { Rails.configuration.x.installation_date }
      let(:stop) { start + 1.month }

      before do
        # Enable opportunity_costs to test total_costs = grid_costs + opportunity_costs
        allow(Setting).to receive(:opportunity_costs).and_return(true)

        # Day 1: High costs
        # grid_import=20kWh * 0.2545 = 5.09 EUR (grid_costs)
        # inverter=50kWh, grid_export=30kWh => self_consumption=20kWh * 0.0832 = 1.664 EUR (opportunity_costs)
        # total = 6.754 EUR
        create_summary(
          date: start + 1.day,
          values: [
            [:grid_import_power, :sum, 20_000],
            [:inverter_power, :sum, 50_000],
            [:inverter_power_1, :sum, 30_000],
            [:inverter_power_2, :sum, 20_000],
            [:grid_export_power, :sum, 30_000],
          ],
        )

        # Day 2: Lower costs
        # grid_import=10kWh * 0.2545 = 2.545 EUR (grid_costs)
        # inverter=40kWh, grid_export=25kWh => self_consumption=15kWh * 0.0832 = 1.248 EUR (opportunity_costs)
        # total = 3.793 EUR
        create_summary(
          date: start + 2.days,
          values: [
            [:grid_import_power, :sum, 10_000],
            [:inverter_power, :sum, 40_000],
            [:inverter_power_1, :sum, 25_000],
            [:inverter_power_2, :sum, 15_000],
            [:grid_export_power, :sum, 25_000],
          ],
        )

        # Day 3: Medium costs
        # grid_import=15kWh * 0.2545 = 3.8175 EUR (grid_costs)
        # inverter=45kWh, grid_export=28kWh => self_consumption=17kWh * 0.0832 = 1.4144 EUR (opportunity_costs)
        # total = 5.2319 EUR
        create_summary(
          date: start + 3.days,
          values: [
            [:grid_import_power, :sum, 15_000],
            [:inverter_power, :sum, 45_000],
            [:inverter_power_1, :sum, 27_000],
            [:inverter_power_2, :sum, 18_000],
            [:grid_export_power, :sum, 28_000],
          ],
        )
      end

      it 'correctly calculates total costs (grid_costs + opportunity_costs) and returns ranking' do
        result = call
        expect(result[0][:date]).to eq(start + 1.day)
        expect(result[0][:value]).to be_within(0.001).of(6.754)
        expect(result[1][:date]).to eq(start + 3.days)
        expect(result[1][:value]).to be_within(0.001).of(5.2319)
        expect(result[2][:date]).to eq(start + 2.days)
        expect(result[2][:value]).to be_within(0.001).of(3.793)
      end

      context 'when for months' do
        let(:period) { :month }

        it 'correctly aggregates total costs by month' do
          # Sum of all three days: 6.754 + 3.793 + 5.2319 = 15.7789
          expect(call).to eq(
            [{ date: start.beginning_of_month, value: 15.7789 }],
          )
        end
      end

      context 'when ascending order' do
        let(:desc) { false }

        it 'returns lowest costs first' do
          expect(call.first[:date]).to eq(start + 2.days)
          expect(call.first[:value]).to eq(3.793)
        end
      end
    end

    context 'when using sql-calculated sensor (savings)' do
      let(:sensor_name) { :savings }
      let(:period) { :day }
      let(:desc) { true }
      let(:start) { Rails.configuration.x.installation_date }
      let(:stop) { start + 1.month }

      before do
        # Day 1: High savings
        # traditional_costs = (30 + 10 + 5) * 0.2545 = 11.4525 EUR
        # solar_price = 20 * 0.2545 - 30 * 0.0832 = 5.09 - 2.496 = 2.594 EUR
        # savings = 11.4525 - 2.594 = 8.8585 EUR
        create_summary(
          date: start + 1.day,
          values: [
            [:house_power, :sum, 30_000],
            [:heatpump_power, :sum, 10_000],
            [:wallbox_power, :sum, 5_000],
            [:grid_import_power, :sum, 20_000],
            [:grid_export_power, :sum, 30_000],
          ],
        )

        # Day 2: Medium savings
        # traditional_costs = (25 + 8 + 3) * 0.2545 = 9.162 EUR
        # solar_price = 15 * 0.2545 - 25 * 0.0832 = 3.8175 - 2.08 = 1.7375 EUR
        # savings = 9.162 - 1.7375 = 7.4245 EUR
        create_summary(
          date: start + 2.days,
          values: [
            [:house_power, :sum, 25_000],
            [:heatpump_power, :sum, 8_000],
            [:wallbox_power, :sum, 3_000],
            [:grid_import_power, :sum, 15_000],
            [:grid_export_power, :sum, 25_000],
          ],
        )

        # Day 3: Low savings
        # traditional_costs = (20 + 5 + 2) * 0.2545 = 6.8715 EUR
        # solar_price = 12 * 0.2545 - 18 * 0.0832 = 3.054 - 1.4976 = 1.5564 EUR
        # savings = 6.8715 - 1.5564 = 5.3151 EUR
        create_summary(
          date: start + 3.days,
          values: [
            [:house_power, :sum, 20_000],
            [:heatpump_power, :sum, 5_000],
            [:wallbox_power, :sum, 2_000],
            [:grid_import_power, :sum, 12_000],
            [:grid_export_power, :sum, 18_000],
          ],
        )
      end

      it 'correctly calculates savings and returns ranking' do
        result = call
        expect(result[0][:date]).to eq(start + 1.day)
        expect(result[0][:value]).to be_within(0.001).of(8.8585)
        expect(result[1][:date]).to eq(start + 2.days)
        expect(result[1][:value]).to be_within(0.001).of(7.4245)
        expect(result[2][:date]).to eq(start + 3.days)
        expect(result[2][:value]).to be_within(0.001).of(5.3151)
      end

      context 'when for months' do
        let(:period) { :month }

        it 'correctly aggregates savings by month' do
          # Sum of all three days: 8.8585 + 7.4245 + 5.3151 = 21.5981
          result = call
          expect(result.size).to eq(1)
          expect(result[0][:date]).to eq(start.beginning_of_month)
          expect(result[0][:value]).to be_within(0.001).of(21.5981)
        end
      end
    end
  end
end

describe Sensor::Data::Series do
  subject(:data) { described_class.new(series_data, timeframe:) }

  let(:timeframe) { Timeframe.new('2025') }

  # Points carry no instant of their own - a Single holds a day-granular
  # Timeframe, not the moment it was built for - so anything pairing a
  # calculated value back with its time reads this list. It used to be derived
  # a second time, in Query::Base, from the same raw_data. Both derivations
  # agreed, but a mismatch would have kept the same LENGTH and therefore moved
  # every calculated value onto a neighbouring timestamp instead of failing.
  describe '#timestamps' do
    let(:series_data) do
      {
        %i[house_power sum sum] => {
          Date.new(2025, 1, 1) => 1.0,
          Date.new(2025, 3, 1) => 3.0,
        },
        # A second sensor on a different grid, so the union matters.
        %i[case_temp avg avg] => {
          Date.new(2025, 2, 1) => 2.0,
        },
      }
    end

    it 'lines up one-to-one with points, in order' do
      expect(data.timestamps.size).to eq(data.points.size)
      expect(data.timestamps).to eq(data.timestamps.sort)
    end

    it 'spans the union across sensors, not one sensor grid' do
      expect(data.timestamps).to eq(
        [Date.new(2025, 1, 1), Date.new(2025, 2, 1), Date.new(2025, 3, 1)],
      )
    end

    # A point holds the value of that instant alone, so pairing it with the
    # wrong timestamp is invisible in the value and only wrong in time - the
    # failure this list exists to prevent.
    it 'pairs each point with the timestamp it was built for' do
      paired = data.timestamps.zip(data.points).to_h

      expect(paired[Date.new(2025, 1, 1)].house_power).to eq(1.0)
      expect(paired[Date.new(2025, 2, 1)].case_temp).to eq(2.0)
      expect(paired[Date.new(2025, 3, 1)].house_power).to eq(3.0)
    end

    it 'is empty when there is nothing to place' do
      expect(described_class.new({}, timeframe:).timestamps).to eq([])
    end
  end

  describe 'initialization' do
    it 'accepts Hash as series_data' do
      expect { described_class.new({}, timeframe:) }.not_to raise_error
    end

    it 'rejects Array as series_data' do
      expect { described_class.new([], timeframe:) }.to raise_error(
        ArgumentError,
        'Series data must be a Hash with sensor keys',
      )
    end

    it 'rejects invalid series_data types' do
      expect { described_class.new('invalid', timeframe:) }.to raise_error(
        ArgumentError,
        'Series data must be a Hash with sensor keys',
      )
    end

    describe 'key format validation' do
      it 'accepts 3-element array keys' do
        series_data = {
          %i[house_power sum sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect do
          described_class.new(series_data, timeframe:)
        end.not_to raise_error
      end

      it 'rejects non-array keys' do
        series_data = { house_power: { Date.new(2025, 1, 1) => 1000.0 } }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Invalid series key format.*Must be Array/,
        )
      end

      it 'rejects array keys with wrong length' do
        series_data = {
          %i[house_power sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Series key must be Array with 3 elements/,
        )
      end

      it 'rejects non-symbol sensor names' do
        series_data = {
          ['house_power', :sum, :sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Sensor name must be a Symbol/,
        )
      end

      it 'rejects invalid aggregation types' do
        series_data = {
          %i[house_power invalid sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Invalid aggregation: :invalid/,
        )
      end

      it 'rejects non-Hash time data' do
        series_data = { %i[house_power sum sum] => 'not a hash' }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Time data.*must be a Hash/,
        )
      end

      it 'rejects non-Date time keys' do
        series_data = { %i[house_power sum sum] => { '2025-01-01' => 1000.0 } }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Time keys must be Date or Time objects/,
        )
      end
    end
  end

  describe 'Use case 4: Series' do
    let(:series_data) do
      {
        %i[house_power sum sum] => {
          Date.new(2025, 1, 1) => 3750.0,
          Date.new(2025, 2, 1) => 3400.0,
          Date.new(2025, 3, 1) => 3200.0,
        },
        %i[case_temp avg min] => {
          Date.new(2025, 1, 1) => 20,
          Date.new(2025, 2, 1) => 24,
          Date.new(2025, 3, 1) => 25,
        },
        %i[case_temp avg max] => {
          Date.new(2025, 1, 1) => 22,
          Date.new(2025, 2, 1) => 26,
          Date.new(2025, 3, 1) => 27,
        },
      }
    end

    it 'requires parameters for series data access' do
      expect { data.house_power }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: house_power\(:sum, :sum\)/,
      )
      expect { data.case_temp }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: case_temp\(:avg, :min\), case_temp\(:avg, :max\)/,
      )
    end

    it 'supports hash return format for method access' do
      expect(data.house_power(:sum, :sum)).to eq(
        {
          Date.new(2025, 1, 1) => 3750.0,
          Date.new(2025, 2, 1) => 3400.0,
          Date.new(2025, 3, 1) => 3200.0,
        },
      )

      expect(data.case_temp(:avg, :min)).to eq(
        {
          Date.new(2025, 1, 1) => 20.0,
          Date.new(2025, 2, 1) => 24.0,
          Date.new(2025, 3, 1) => 25.0,
        },
      )
    end

    it 'raises exception for non-existent aggregation combinations' do
      expect { data.house_power(:avg, :min) }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: house_power\(:sum, :sum\)/,
      )
      expect { data.case_temp(:sum, :sum) }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: case_temp\(:avg, :min\), case_temp\(:avg, :max\)/,
      )
    end

    it 'supports empty time series Hash (different from non-existent key)' do
      empty_series_data = {
        %i[house_power sum sum] => {
          # Empty Hash - valid but no data
        },
        %i[case_temp avg min] => {
          Date.new(2025, 1, 1) => 20.0,
          Date.new(2025, 2, 1) => 24.0,
        },
      }
      empty_data = described_class.new(empty_series_data, timeframe:)

      # Empty Hash is valid and returns empty result
      expect(empty_data.house_power(:sum, :sum)).to eq({})
      # Non-empty data works normally
      expect(empty_data.case_temp(:avg, :min)).to be_a(Hash)
      expect(empty_data.case_temp(:avg, :min).keys.count).to eq(2)
    end

    it 'requires exactly 2 parameters for method access' do
      expect { data.house_power(:sum) }.to raise_error(ArgumentError)
      expect { data.house_power(:sum, :sum, :extra) }.to raise_error(
        ArgumentError,
      )
    end

    it 'extracts unique sensor names correctly' do
      expect(data.sensor_names).to contain_exactly(:house_power, :case_temp)
    end

    it 'is a series data type' do
      expect(data.series?).to be true
      expect(data.single?).to be false
    end
  end

  describe 'edge cases' do
    let(:series_data) { {} }

    it 'handles empty data' do
      expect(data.sensor_names).to eq([])
    end

    it 'fails for non-existent sensors' do
      expect { data.non_existent_sensor }.to raise_error(NoMethodError)
    end
  end

  describe '#reporting_sensor_names' do
    let(:jan) { Date.new(2025, 1, 1) }
    let(:feb) { Date.new(2025, 2, 1) }
    let(:mar) { Date.new(2025, 3, 1) }

    context 'when a sensor starts and another stops mid-window' do
      let(:series_data) do
        {
          %i[inverter_power_1 sum sum] => {
            jan => 1.0,
            feb => 2.0,
            mar => 3.0,
          },
          %i[inverter_power_2 sum sum] => {
            jan => nil,
            feb => nil,
            mar => 3.0,
          },
          %i[house_power sum sum] => {
            jan => 1.0,
            feb => nil,
            mar => nil,
          },
        }
      end

      it 'names a sensor only from its first value to its last' do
        expect(data.reporting_sensor_names).to eq(
          [
            %i[inverter_power_1 house_power],
            %i[inverter_power_1],
            %i[inverter_power_1 inverter_power_2],
          ],
        )
      end
    end

    context 'when a sensor misses a point inside its window' do
      let(:series_data) do
        {
          %i[inverter_power_1 sum sum] => {
            jan => 1.0,
            feb => nil,
            mar => 3.0,
          },
        }
      end

      it 'keeps naming it, because that nil is a gap' do
        expect(data.reporting_sensor_names[1]).to eq(%i[inverter_power_1])
      end
    end

    context 'when a sensor carries only nils' do
      let(:series_data) do
        {
          %i[inverter_power_1 sum sum] => {
            jan => 1.0,
          },
          %i[inverter_power_2 sum sum] => {
            jan => nil,
          },
        }
      end

      it 'leaves it out everywhere' do
        expect(data.reporting_sensor_names).to eq([%i[inverter_power_1]])
      end
    end

    # Both aggregations of one field arrive as separate keys, and the window
    # is the sensor's, not one key's.
    context 'with several aggregation keys for the same sensor' do
      let(:series_data) do
        {
          %i[inverter_power_1 sum sum] => {
            jan => 1.0,
            feb => nil,
          },
          %i[inverter_power_1 max max] => {
            jan => nil,
            feb => 2.0,
          },
        }
      end

      it 'spans what any of them delivers' do
        expect(data.reporting_sensor_names).to eq(
          [%i[inverter_power_1], %i[inverter_power_1]],
        )
      end
    end
  end

  describe 'empty time series' do
    let(:series_data) { { %i[house_power sum sum] => {} } }

    it 'requires parameters but returns empty hash for valid method access' do
      expect { data.house_power }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: house_power\(:sum, :sum\)/,
      )
      expect(data.house_power(:sum, :sum)).to eq({})
    end
  end
end

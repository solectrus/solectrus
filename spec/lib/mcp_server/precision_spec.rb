describe McpServer::Precision do
  describe '.round' do
    # One row per unit the policy covers: what goes in, what comes out, and -
    # just as much part of the contract - which JSON type it comes out as.
    {
      watt: [170.60000000000002, 170.6, Float],
      watt_hour: [1_053_570.0006654165, 1_053_570, Integer],
      watt_per_kwp: [612.3456789, 612.3, Float],
      watt_hour_per_kwp: [4123.987654, 4124, Integer],
      money: [53.612878698556365, 53.61, Float],
      # A tariff rounded to 2 decimals would not be rounded but lost, so this
      # is the one unit that stays fine-grained.
      money_per_kwh: [0.32714285714, 0.3271, Float],
      percent: [99.80449960264723, 99.8, Float],
      celsius: [5.981991935745264, 6.0, Float],
      unitless: [4.2384615384, 4.24, Float],
      gram: [158_295.4999, 158_295, Integer],
    }.each do |unit, (input, expected, type)|
      context "with unit #{unit}" do
        it "rounds #{input} to #{expected}" do
          expect(described_class.round(input, unit)).to eq(expected)
        end

        it "serializes as #{type}" do
          expect(described_class.round(input, unit)).to be_a(type)
        end
      end
    end

    it 'accepts the unit as a string' do
      expect(described_class.round(170.60000000000002, 'watt')).to eq(170.6)
    end

    # A percent that happens to be integral must not slip back to Integer -
    # otherwise one array mixes 78 and 78.3 and a client cannot tell whether
    # the first one was rounded.
    it 'keeps a decimal unit a Float even for a whole number' do
      expect(described_class.round(78, :percent)).to be(78.0)
    end

    it 'keeps an integral input of a 0-decimal unit an Integer' do
      expect(described_class.round(1234, :watt_hour)).to be(1234)
    end

    it 'converts a BigDecimal to the plain JSON type' do
      expect(described_class.round(BigDecimal('0.3271'), :money_per_kwh)).to be(0.3271)
    end

    it 'passes nil through' do
      expect(described_class.round(nil, :watt)).to be_nil
    end

    it 'passes a boolean through' do
      expect(described_class.round(false, :boolean)).to be(false)
    end

    it 'passes a string through' do
      expect(described_class.round('ok', :string)).to eq('ok')
    end

    # An unknown unit must not silently lose digits; better a raw value than a
    # wrong one.
    it 'passes a value with an unknown unit through unrounded' do
      expect(described_class.round(1.23456, :parsec)).to eq(1.23456)
    end

    it 'passes a value without a unit through unrounded' do
      expect(described_class.round(1.23456, nil)).to eq(1.23456)
    end
  end

  describe 'DECIMALS' do
    # The policy has to cover every unit a sensor can actually carry, minus the
    # non-numeric ones - otherwise a sensor quietly falls back to raw floats.
    it 'covers every numeric unit a sensor can report' do
      numeric_units = Sensor::Config.sensors.to_set(&:unit) - %i[boolean string]

      expect(described_class::DECIMALS.keys).to include(*numeric_units)
    end

    # mcp_unit refines :watt into these after aggregation, so they need an
    # entry of their own.
    it 'covers the units aggregation introduces' do
      expect(described_class::DECIMALS.keys).to include(
        :watt_hour,
        :watt_per_kwp,
        :watt_hour_per_kwp,
      )
    end
  end
end

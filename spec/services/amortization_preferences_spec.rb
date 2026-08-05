describe AmortizationPreferences do
  let(:defaults) do
    {
      period_years: AmortizationCalculator::DEFAULT_PERIOD_YEARS,
      interest_rate: AmortizationCalculator::DEFAULT_INTEREST_RATE,
    }
  end

  describe 'without anything submitted or stored' do
    subject(:preferences) { described_class.new }

    it 'falls back to the defaults' do
      expect(preferences.to_h).to eq(defaults)
    end

    it 'is not customized' do
      expect(preferences).not_to be_customized
    end
  end

  describe 'with a slider submission' do
    subject(:preferences) do
      described_class.new(
        submitted: {
          'period_years' => '25',
          'interest_rate' => '2.5',
        },
      )
    end

    it 'takes the submitted values' do
      expect(preferences.to_h).to eq(period_years: 25, interest_rate: 2.5)
    end
  end

  describe 'with a cookie' do
    subject(:preferences) { described_class.new(cookie:) }

    let(:cookie) { { period_years: 15, interest_rate: 1.5 }.to_json }

    it 'takes the stored values' do
      expect(preferences.to_h).to eq(period_years: 15, interest_rate: 1.5)
    end

    it 'is customized' do
      expect(preferences).to be_customized
    end

    context 'when a slider was moved as well' do
      subject(:preferences) do
        described_class.new(submitted: { 'period_years' => '25' }, cookie:)
      end

      it 'prefers the submission, per parameter' do
        # Only the period was moved, so the rate stays what the cookie says.
        expect(preferences.to_h).to eq(period_years: 25, interest_rate: 1.5)
      end
    end

    context 'when it is malformed' do
      let(:cookie) { 'not json at all' }

      it 'falls back to the defaults instead of failing' do
        expect(preferences.to_h).to eq(defaults)
      end
    end

    context 'when it holds something other than an object' do
      let(:cookie) { '[1, 2, 3]'.to_json }

      it 'falls back to the defaults' do
        expect(preferences.to_h).to eq(defaults)
      end
    end

    context 'when it has been tampered with' do
      let(:cookie) { { period_years: 999, interest_rate: -5 }.to_json }

      it 'clamps into the allowed ranges' do
        expect(preferences.to_h).to eq(
          period_years: AmortizationCalculator::PERIOD_RANGE.max,
          interest_rate: AmortizationCalculator::INTEREST_RANGE.min,
        )
      end
    end
  end
end

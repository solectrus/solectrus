describe AmortizationPage do
  subject(:page) { described_class.shell(visibility:, preferences:) }

  let(:visibility) do
    instance_double(AmortizationVisibility, denial_reason:)
  end
  let(:denial_reason) { nil }
  let(:preferences) { AmortizationPreferences.new }

  describe '#state' do
    # Which reason applies is the visibility's business (and its spec's); the
    # page only has to prefer it over anything it could say itself.
    context 'when the viewer may not see the calculation' do
      let(:denial_reason) { :restricted }

      it { expect(page.state).to eq(:restricted) }
    end

    context 'without any cash flows' do
      it { expect(page.state).to eq(:no_cash_flows) }
    end

    context 'with cash flows' do
      before do
        CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')
      end

      it { expect(page.state).to eq(:calculation) }
    end
  end

  describe 'the daily summaries' do
    before do
      CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')
    end

    context 'when they are complete' do
      before do
        allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
      end

      it 'expects a calculation' do
        expect(page).to be_calculation_expected
      end
    end

    context 'when days are missing' do
      before do
        allow(Summary).to receive(:missing_or_stale_days_for).and_return(
          [Date.new(2024, 6, 14)],
        )
      end

      it 'reports them and expects no calculation yet' do
        aggregate_failures do
          expect(page.missing_or_stale_days).to eq([Date.new(2024, 6, 14)])
          expect(page).not_to be_calculation_expected
        end
      end

      it 'does not compute anything on incomplete data' do
        allow(AmortizationCalculator).to receive(:result)

        expect(described_class.detail(visibility:, preferences:).result).to be_nil
        expect(AmortizationCalculator).not_to have_received(:result)
      end

      # The builder is all the detail frame would have to show, and the shell
      # knows it already - no point letting the frame fetch it.
      it 'has the detail ready for the shell to render inline' do
        expect(page).to be_detail_ready
      end
    end

    context 'when there is nothing to calculate anyway' do
      let(:denial_reason) { :unavailable }

      it 'does not even ask for them' do
        allow(Summary).to receive(:missing_or_stale_days_for)

        expect(page.missing_or_stale_days).to eq([])
        expect(Summary).not_to have_received(:missing_or_stale_days_for)
      end
    end
  end

  describe '#result' do
    before do
      CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')
      allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
      allow(AmortizationCalculator).to receive_messages(
        result: :computed,
        cached_result: nil,
      )
    end

    it 'is left to the detail frame when the shell finds no cached one' do
      aggregate_failures do
        expect(page.result).to be_nil
        expect(page).not_to be_detail_ready
        expect(AmortizationCalculator).not_to have_received(:result)
      end
    end

    it 'is taken along by the shell when it is already cached' do
      allow(AmortizationCalculator).to receive(:cached_result).and_return(:cached)

      aggregate_failures do
        expect(page.result).to eq(:cached)
        expect(page).to be_detail_ready
        expect(AmortizationCalculator).not_to have_received(:result)
      end
    end

    it 'is computed for the detail frame' do
      expect(described_class.detail(visibility:, preferences:).result).to eq(:computed)
    end

    it 'is computed with the effective slider parameters' do
      described_class.detail(
        visibility:,
        preferences: AmortizationPreferences.new(submitted: { 'period_years' => '25' }),
      ).result

      expect(AmortizationCalculator).to have_received(:result).with(
        period_years: 25,
        interest_rate: AmortizationCalculator::DEFAULT_INTEREST_RATE,
      )
    end
  end
end

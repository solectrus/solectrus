describe Insights::TrendRow::Component, type: :component do
  subject(:component) { described_class.new(trend:, label: 'Previous year', url: '/2024') }

  let(:sensor) { double('Sensor', trend_aggregation: :sum, unit: :watt) }
  let(:base_timeframe) { Timeframe.new('2024') }
  let(:trend) do
    instance_double(
      Trend,
      comparable?: true,
      same?: false,
      diff: -334_000,
      percent: -3.2,
      more_is_better?: true,
      sensor:,
      base_value: 10_402_000,
      base_timeframe:,
      precision: 0,
    )
  end

  it 'shows the trend, the earlier period and its value' do
    page = render_inline(component)

    expect(page.css('a.insights-row-link').attr('href').value).to eq('/2024')
    expect(page.css('.insights-row-value .trend-indicator').text).to include('-3 %')
    expect(page.css('.insights-row-label-note').text).to eq('2024')
    expect(page.css('.tooltip-detail').text).to eq('10,402 kWh')
  end

  it 'keeps a short period beside the label' do
    page = render_inline(component)

    expect(page.css('.insights-row-label-note-long')).to be_empty
  end

  context 'with a long period' do
    let(:base_timeframe) { Timeframe.new('2025-01-01..2025-09-27') }

    it 'lets the period take a line of its own' do
      page = render_inline(component)

      expect(page.css('.insights-row-label-note-long').text).to eq('Jan 1 – Sep 27, 2025')
    end
  end

  describe '#period' do
    subject(:period) do
      render_inline(component)
      component.period
    end

    it { is_expected.to eq('2024') }

    context 'with a month' do
      let(:base_timeframe) { Timeframe.new('2025-12') }

      it { is_expected.to eq('Dec 2025') }
    end

    context 'with days of one month' do
      let(:base_timeframe) { Timeframe.new('2026-08-01..2026-08-27') }

      it { is_expected.to eq('Aug 1–27, 2026') }

      it 'names them in German' do
        I18n.with_locale(:de) { expect(period).to eq('1.–27. Aug 2026') }
      end
    end

    context 'with days of one year' do
      let(:base_timeframe) { Timeframe.new('2025-01-01..2025-09-27') }

      it { is_expected.to eq('Jan 1 – Sep 27, 2025') }
    end

    context 'with days of two years' do
      let(:base_timeframe) { Timeframe.new('2024-12-15..2025-01-14') }

      it { is_expected.to eq(base_timeframe.localized) }
    end
  end

  context 'without a comparable trend' do
    let(:trend) { instance_double(Trend, comparable?: false) }

    it 'renders nothing' do
      expect(render_inline(component).to_html).to be_empty
    end
  end

  context 'without a trend' do
    let(:trend) { nil }

    it 'renders nothing' do
      expect(render_inline(component).to_html).to be_empty
    end
  end
end

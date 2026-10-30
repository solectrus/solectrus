describe Car::SavingsRow::Component, type: :component do
  subject(:html) { render_inline(described_class.new(report:)) }

  let(:comparison) { instance_double(Car::Comparison, ready?: true) }
  let(:savings) { 75 }
  let(:report) { instance_double(Car::Report, timeframe: Timeframe.new('2026-10'), car: nil, comparison:) }

  # The row, which links to the comparison of the month
  def link = html.at_css('a[href="/cars/savings/2026-10"]')

  before { allow(Car::ComparisonAmounts).to receive(:new).with(comparison).and_return(instance_double(Car::ComparisonAmounts, savings:)) }

  it 'shows the savings in green and links to the comparison of the month' do
    expect(link.text.squish).to eq('Savings against a combustion car 75 €')
    expect(link.at_css('.text-signal-positive').text.squish).to eq('75 €')
  end

  context 'with a loss' do
    let(:savings) { -12 }

    it 'shows it in red' do
      expect(link.at_css('.text-signal-negative').text.squish).to eq('-12 €')
    end
  end

  # The comparison page says what it lacks
  context 'without a compared distance' do
    let(:comparison) { instance_double(Car::Comparison, ready?: false) }

    it 'keeps the row with a dash' do
      expect(link.text.squish).to eq('Savings against a combustion car –')
    end
  end

  # The whole time has no timeframe in the address, and one car keeps its id
  context 'with the whole time of one car' do
    let(:report) { instance_double(Car::Report, timeframe: Timeframe.new('all'), car: Car.new(id: 2), comparison:) }

    it 'links to the comparison of the car' do
      expect(html.at_css('a')['href']).to eq('/cars/2/savings')
    end
  end

  # While the figures load, the row keeps its place without a link
  context 'without a report' do
    let(:report) { nil }

    it 'shows the label with a pulsing bar' do
      expect(html.css('a')).to be_empty
      expect(html.text.squish).to eq('Savings against a combustion car')
      expect(html.css('.animate-pulse').size).to eq(1)
    end
  end
end

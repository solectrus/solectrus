describe Top10::Chart::Component, type: :component do
  subject(:html) do
    render_inline(described_class.new(sensor_name: :outdoor_temp, period: 'day', sort: ActiveSupport::StringInquirer.new('desc'), calc: 'max'))
  end

  # The highest temperature of seven past days, from above the warmest stop of
  # the color scale to below the coldest one. The bars get shorter step by
  # step, so each width decides anew where the value goes.
  let(:temperatures) { [45, 20, 15, 7, 3, 1, -20] }

  before do
    travel_to Date.new(2026, 6, 15)

    temperatures.each_with_index do |value, index|
      create_summary(date: Date.new(2026, 6, 1) + index, values: [[:outdoor_temp, :max, value]])
    end
  end

  def rows = html.css('a.table-row')

  def gradient(row) = row.at_css('.bar-gradient-bg')['style']

  # The classes that show or hide an element, for example "hidden sm:inline"
  def visibility(element) = element['class'].split.grep(/\A([a-z]+:)?(hidden|inline)\z/)

  def inside(row) = visibility(row.at_css('.bar-gradient-bg + span'))

  def beside(row) = visibility(row.css('.flex.items-center.gap-3 > span').last)

  it 'ranks the days, none of them today' do
    expect(rows.size).to eq(7)
    expect(rows.first.css('.text-gray-700').size).to eq(2)
  end

  describe 'the color of a bar' do
    let(:plain) { /--top10-gradient-to: var\(--color-[\w-]+\)(;|\z)/ }
    let(:mix) { /color-mix\(in oklab, var\(--color-[\w-]+\) [\d.]+%, var\(--color-[\w-]+\) [\d.]+%\)/ }

    it 'follows the color scale of the sensor' do
      expect(rows.css('.bar-gradient-bg.top10-gradient').size).to eq(7)
    end

    it 'ends in the color of the nearest stop outside the scale' do
      expect(gradient(rows.first)).to match(plain)
      expect(gradient(rows.last)).to match(plain)
    end

    # 1 degree lies between two stops of the scale
    it 'ends in a mix of two stops between them, in light and in dark mode' do
      expect(gradient(rows[5])).to match(/--top10-gradient-to: #{mix}/)
      expect(gradient(rows[5])).to match(/--top10-gradient-to-dark: #{mix}/)
    end
  end

  describe 'the place of the value' do
    # Where the value shows inside the bar, it hides beside it, and the other
    # way round, at every screen width
    it 'shows each value once' do
      swapped = rows.map { |row| inside(row).map { it.sub(/hidden|inline/, 'hidden' => 'inline', 'inline' => 'hidden') } }

      expect(rows.map { beside(it) }).to eq(swapped)
    end

    it 'shows the value inside the longest bar' do
      expect(inside(rows.first)).to eq(%w[inline])
    end

    it 'needs a wider screen for the value inside a shorter bar' do
      widths = rows.drop(1).first(4).map { %w[sm md lg xl 2xl].index(inside(it).last.split(':').first) }

      expect(widths).to eq(widths.compact.sort.uniq)
    end

    it 'shows the value beside a very short bar' do
      expect(beside(rows.last)).to eq(%w[inline])
    end
  end

  it 'shows a temperature with its own unit' do
    expect(rows.first.text).to include('45')
    expect(rows.first.text).to include('°C')
  end
end

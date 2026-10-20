describe Ui::InfoIcon::Component, type: :component do
  it 'splits the text into paragraphs' do
    result = render_inline(described_class.new(text: "First.\n\nSecond."))

    expect(result.css('p').map(&:text)).to eq(%w[First. Second.])
  end

  it 'makes a list of the lines that start with a dash, below the other lines' do
    result = render_inline(described_class.new(text: "Intro.\n\nData needed:\n- Odometer\n- Fuel prices"))

    expect(result.css('p').map(&:text)).to eq(['Intro.', 'Data needed:'])
    expect(result.css('ul li').map(&:text)).to eq(['Odometer', 'Fuel prices'])
  end
end

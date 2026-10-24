describe TailwindFormBuilder do
  def placeholder(**)
    builder = described_class.new(:charging_session, ChargingSession.new, helper, {})
    Nokogiri::HTML5.fragment(builder.text_area(:note, **)).at_css('textarea')['placeholder']
  end

  describe '#text_area' do
    it 'shows the label as the placeholder' do
      expect(placeholder(label: 'Comment')).to eq('Comment')
    end

    it 'shows the name without a label' do
      expect(placeholder(label: false)).to eq(ChargingSession.human_attribute_name(:note))
    end
  end

  describe '#number_field' do
    def inputmode(**)
      builder = described_class.new(:charging_session, ChargingSession.new, helper, {})
      Nokogiri::HTML5.fragment(builder.number_field(:kwh, **)).at_css('input')['inputmode']
    end

    it 'shows the decimal keypad for a field without negative values' do
      expect(inputmode(in: 0..10_000)).to eq('decimal')
      expect(inputmode(min: 0.1)).to eq('decimal')
    end

    it 'keeps the full keyboard for a field that takes a negative value' do
      expect(inputmode(in: -10..10)).to be_nil
      expect(inputmode).to be_nil
    end
  end
end

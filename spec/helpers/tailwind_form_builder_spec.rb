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
end

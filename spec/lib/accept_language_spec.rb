describe AcceptLanguage do
  def locale_from(header)
    described_class.locale_from(header, %i[en de])
  end

  it 'picks the language of a region' do
    expect(locale_from('de-AT')).to eq(:de)
  end

  it 'follows the quality values' do
    expect(locale_from('fr;q=1.0, en;q=0.5, de;q=0.8')).to eq(:de)
  end

  it 'keeps the order of the header for an equal quality' do
    expect(locale_from('en-GB, de')).to eq(:en)
  end

  it 'skips a language that the app does not offer' do
    expect(locale_from('fr-FR, fr;q=0.9, de;q=0.7')).to eq(:de)
  end

  it 'ignores a rejected language and a wildcard' do
    expect(locale_from('de;q=0, *, en;q=0.1')).to eq(:en)
  end

  it 'compares without case' do
    expect(locale_from('DE-de')).to eq(:de)
  end

  it 'returns nil for no match' do
    aggregate_failures do
      expect(locale_from('fr')).to be_nil
      expect(locale_from(nil)).to be_nil
      expect(locale_from('')).to be_nil
      expect(locale_from(';;,')).to be_nil
    end
  end
end

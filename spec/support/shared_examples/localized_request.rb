shared_examples_for 'localized request' do |action|
  before { allow(I18n).to receive(:with_locale) }

  it 'uses English as default' do
    get action

    expect(I18n).to have_received(:with_locale).with(:en)
  end

  it 'uses German if requested' do
    get action, headers: { 'Accept-Language' => 'de-DE' }

    expect(I18n).to have_received(:with_locale).with(:de)
  end

  it 'uses English as fallback' do
    get action, headers: { 'Accept-Language' => 'fr' }

    expect(I18n).to have_received(:with_locale).with(:en)
  end
end

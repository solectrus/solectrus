describe SummaryStatus::Component, type: :component do
  it 'shows the share of fresh days with a reset' do
    render_inline(described_class.new(completion_rate: 87.6))

    aggregate_failures do
      expect(page).to have_css('turbo-frame#summaries')
      expect(page).to have_text(I18n.t('settings.general.summaries.fresh_percentage', value: 87))
      expect(page).to have_css("form[action='/summaries']")
    end
  end

  it 'has no reset without a summary' do
    render_inline(described_class.new(completion_rate: nil))

    aggregate_failures do
      expect(page).to have_text(I18n.t('settings.general.summaries.zero'))
      expect(page).to have_no_css('form')
    end
  end
end

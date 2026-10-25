describe Ui::Message::Component, type: :component do
  it 'renders its slots' do
    render_inline(described_class.new) do |c|
      c.with_title { 'Not found' }
      c.with_body { 'The page does not exist.' }
      c.with_footer { 'Home' }
    end

    aggregate_failures do
      expect(page).to have_css('h1', text: 'Not found')
      expect(page).to have_text('The page does not exist.')
      expect(page).to have_text('Home')
    end
  end

  it 'leaves out an empty slot' do
    render_inline(described_class.new) { |c| c.with_title { 'Error' } }

    expect(page).to have_no_css('.mt-10')
  end
end

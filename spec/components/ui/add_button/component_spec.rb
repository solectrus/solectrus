describe Ui::AddButton::Component, type: :component do
  it 'opens the form of a new entry in the modal' do
    render_inline(described_class.new(href: '/prices/new?price%5Bname%5D=electricity', label: 'New price'))

    link = page.find('a[href="/prices/new?price%5Bname%5D=electricity"]')
    aggregate_failures do
      expect(link['data-turbo-frame']).to eq('modal')
      expect(link['data-controller']).to include('modal-launcher')
      expect(link['aria-label']).to eq('New price')
      expect(link['class']).to include('hidden', 'lg:flex')
      expect(link).to have_css('.fa-plus')
      expect(link.text).to be_empty
    end
  end
end

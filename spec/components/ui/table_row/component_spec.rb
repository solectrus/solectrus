describe Ui::TableRow::Component, type: :component do
  before do
    helpers = vc_test_controller.helpers

    render_inline(described_class.new(href: '/edit', nav_title: 'Edit price', css_class: 'grid')) do |row|
      helpers.safe_join([row.link(css_class: 'truncate') { '01.01.2026' }, helpers.tag.div('Note')])
    end
  end

  it 'lets the whole row open its link' do
    row = page.find('div.grid.cursor-pointer')

    expect(row['data-controller']).to eq('ui--table-row--component')
    expect(row['data-action']).to eq('click->ui--table-row--component#open')
    expect(row).to have_text('Note')
  end

  # The controller points the link to the modal from lg up
  it 'renders the link around the main value, one level down on a phone' do
    link = page.find('a.truncate[href="/edit"]', text: '01.01.2026')

    expect(link['data-nav-title']).to eq('Edit price')
    expect(link['data-turbo-frame']).to be_nil
    expect(link['data-turbo-prefetch']).to eq('false')
    expect(link['data-ui--table-row--component-target']).to eq('link')
  end

  it 'renders a chevron for a phone' do
    expect(page).to have_css('div.grid > .fa-chevron-right.lg\:hidden')
  end
end

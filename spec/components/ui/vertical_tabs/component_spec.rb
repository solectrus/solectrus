describe Ui::VerticalTabs::Component, type: :component do
  before do
    render_inline(described_class.new) do |c|
      c.with_tab(id: 'inverter', label: 'Inverter') { 'First panel' }
      c.with_tab(id: 'grid', label: 'Grid') { 'Second panel' }
    end
  end

  it 'selects the first tab and shows its panel alone' do
    aggregate_failures do
      expect(page).to have_css('a#inverter-tab[role="tab"][aria-selected="true"][aria-controls="inverter"]')
      expect(page).to have_css('a#grid-tab[aria-selected="false"]')
      expect(page).to have_css('#inverter[role="tabpanel"][aria-labelledby="inverter-tab"]', text: 'First panel')
      expect(page).to have_css('#grid[hidden]', visible: :hidden)
    end
  end
end

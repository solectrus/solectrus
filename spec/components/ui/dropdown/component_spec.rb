describe Ui::Dropdown::Component, type: :component do
  def item(name, id, current: false)
    Ui::MenuItem::Component.new(name:, id:, href: "/#{id}", current:)
  end

  context 'with one choice' do
    before do
      render_inline(
        described_class.new(
          name: 'calc',
          items: [item('Sum', 'sum', current: true), item('Maximum', 'max')],
          selected: 'sum',
          label: 'Calculation',
        ),
      )
    end

    it 'selects the current option of the select of a phone' do
      select = page.find('select[aria-label="Calculation"]', visible: :all)

      aggregate_failures do
        expect(select.all('option', visible: :all).map(&:text)).to eq(%w[Sum Maximum])
        expect(select.find('option[selected]', visible: :all).text).to eq('Sum')
      end
    end
  end

  # Several choices at once, one group for each
  context 'with choices' do
    before do
      render_inline(
        described_class.new(
          name: 'options',
          items: [
            { name: 'Calculation', items: [item('Sum', 'sum', current: true), item('Maximum', 'max')] },
            { name: 'Order', items: [item('Descending', 'desc', current: true), item('Ascending', 'asc')] },
          ],
          display_name: 'Options',
          choices: true,
          label: 'Options',
        ),
      )
    end

    it 'shows the menu on a phone too, without a native select' do
      aggregate_failures do
        expect(page).to have_no_select(visible: :all)
        expect(page).to have_css('button[aria-label="Options"]', text: 'Options')
      end
    end

    it 'marks the current entry of each group with a check, not in bold' do
      sum = page.find('[role="menu"] a', text: 'Sum', visible: :all)
      descending = page.find('[role="menu"] a', text: 'Descending', visible: :all)
      maximum = page.find('[role="menu"] a', text: 'Maximum', visible: :all)

      aggregate_failures do
        expect(sum).to have_css('.fa-check', visible: :all)
        expect(descending).to have_css('.fa-check', visible: :all)
        expect(maximum).to have_no_css('.fa-check', visible: :all)
        expect(sum[:class]).not_to include('font-bold')
      end
    end
  end
end

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

  context 'with a leading visual of the selected item' do
    before do
      render_inline(
        described_class.new(
          name: 'car',
          items: [
            Ui::MenuItem::Component.new(name: 'Zoe', id: '1', href: '/1', leading: '<i class="lead"></i>'.html_safe),
            item('Other', '2'),
          ],
          selected: '1',
        ),
      )
    end

    it 'shows it in front of the select of a phone too' do
      expect(page).to have_css('div:has(> select[name="car"]) > span > i.lead', visible: :all)
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

  # A long menu spreads into two columns, and the top item then stands
  # centered above them
  describe 'the columns of a menu' do
    subject(:menu) { page.find('[role="menu"]', visible: :all) }

    before do
      render_inline(
        described_class.new(
          name: 'sensor',
          items: Array.new(count) { item("Item #{it}", "item-#{it}") },
          top_item: item('Top', 'top'),
        ),
      )
    end

    let(:top) { menu.find('a', text: 'Top', visible: :all) }

    context 'with up to 10 items' do
      let(:count) { 10 }

      it 'shows one column with the top item at its start' do
        aggregate_failures do
          expect(menu).to have_css('div.columns-1', visible: :all)
          expect(top[:class]).not_to include('justify-center')
        end
      end
    end

    context 'with 11 to 14 items' do
      let(:count) { 11 }

      it 'shows two columns on a short screen only' do
        aggregate_failures do
          expect(menu).to have_css('div.columns-1.short\:columns-2', visible: :all)
          expect(top[:class]).to include('short:flex short:justify-center')
        end
      end
    end

    context 'with more than 14 items' do
      let(:count) { 15 }

      it 'always shows two columns' do
        aggregate_failures do
          expect(menu).to have_css('div.columns-2', visible: :all)
          expect(top[:class]).to include('flex justify-center')
          expect(top[:class]).not_to include('short:')
        end
      end
    end
  end

  context 'with groups and a top item' do
    before do
      render_inline(
        described_class.new(
          name: 'sensor',
          items: [
            { name: 'Source', items: [item('Solar', 'solar')] },
            { name: 'Usage', items: [item('House', 'house')] },
          ],
          top_item: item('Top', 'top'),
        ),
      )
    end

    it 'puts the groups in a grid and leaves the top item at its start' do
      top = page.find('[role="menu"] a', text: 'Top', visible: :all)

      aggregate_failures do
        expect(page).to have_css('[role="menu"] div.grid', visible: :all)
        expect(top[:class]).not_to include('justify-center')
      end
    end
  end

  # An item without an icon keeps the space of one, so the names stand in a
  # column
  context 'with an icon on some items' do
    before do
      render_inline(
        described_class.new(
          name: 'nav',
          items: [
            Ui::MenuItem::Component.new(name: 'Home', id: 'home', href: '/home', icon: 'house'),
            item('Other', 'other'),
          ],
        ),
      )
    end

    it 'leaves the space of the icon empty' do
      other = page.find('[role="menu"] a', text: 'Other', visible: :all)

      expect(other).to have_css('span.w-6.block', visible: :all)
    end
  end

  it 'refuses an unknown position of the menu' do
    component = described_class.new(name: 'sensor', items: [item('Solar', 'solar')], menu_position: :left)

    expect { render_inline(component) }.to raise_error(ArgumentError, /Unknown menu_position: :left/)
  end
end

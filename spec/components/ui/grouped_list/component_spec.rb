describe Ui::GroupedList::Component, type: :component do
  def render_list(header: nil, footer: nil, &)
    render_inline(described_class.new(header:, footer:), &)
  end

  it 'puts a header above the card and a footer below it' do
    html = render_list(header: 'Appearance', footer: 'Applies to this device') do |list|
      list.with_cell(name: 'Language')
    end

    aggregate_failures do
      expect(html.at('section h2').text).to eq('Appearance')
      expect(html.at('section ul + div').text.strip).to eq('Applies to this device')
    end
  end

  it 'renders nothing without a cell' do
    html = render_list(header: 'Empty')

    expect(html.to_html.strip).to be_empty
  end

  describe 'a cell' do
    def cell_html(**)
      render_list { |list| list.with_cell(name: 'Name', **) }.at('li')
    end

    it 'links one level down with a chevron, which only a phone shows' do
      li = cell_html(href: '/top10')
      link = li.at('a')

      aggregate_failures do
        expect(link['href']).to eq('/top10')
        expect(link['target']).to be_nil
        expect(li.at('.fa-chevron-right')['class']).to include('lg:hidden')
      end
    end

    it 'slides to a page with a title bar' do
      link = cell_html(href: '/top10', slide: true, plain: true).at('a')

      aggregate_failures do
        expect(link['data-nav-title']).to eq('Name')
        expect(link['data-nav-plain']).to eq('true')
      end
    end

    it 'does not slide without a title bar on the next page' do
      expect(cell_html(href: '/inverter').at('a')['data-nav-title']).to be_nil
    end

    it 'opens another site in a new tab, with an arrow out of a box' do
      li = cell_html(href: 'https://solectrus.de')

      aggregate_failures do
        expect(li.at('a')['target']).to eq('_blank')
        expect(li.at('a')['rel']).to eq('noopener')
        expect(li.at_css('.fa-arrow-up-right-from-square')).to be_present
      end
    end

    it 'shows the arrow for a link of the app that leaves for another site' do
      li = cell_html(href: '/registration', external: true)

      aggregate_failures do
        expect(li.at('a')['target']).to be_nil
        expect(li.at_css('.fa-arrow-up-right-from-square')).to be_present
      end
    end

    it 'runs an action as a button' do
      button = cell_html(data: { action: 'click->fullscreen#on' }).at('button')

      aggregate_failures do
        expect(button['type']).to eq('button')
        expect(button['data-action']).to eq('click->fullscreen#on')
      end
    end

    it 'holds a control at the right and reacts to no tap itself' do
      html =
        render_list do |list|
          list.with_cell(name: 'Theme') { |cell| cell.with_accessory { '<input type="radio">'.html_safe } }
        end

      aggregate_failures do
        expect(html.at_css('li > div input[type="radio"]')).to be_present
        expect(html.at_css('li a, li > button')).to be_nil
      end
    end

    it 'paints a destructive action red, without a chevron' do
      li = cell_html(href: '/logout', destructive: true)

      aggregate_failures do
        expect(li.at_css('.text-signal-negative').text.strip).to eq('Name')
        expect(li.at_css('.fa-chevron-right')).to be_nil
      end
    end

    it 'shows a badge with a count, and none for zero' do
      expect(cell_html(href: '/notifications', badge_count: 3).at('[data-notification-badge]').text.strip).to eq('3')
      expect(cell_html(href: '/notifications', badge_count: 0).at_css('[data-notification-badge]')).to be_nil
    end

    it 'gives its data to the row, so a rule can hide the whole row' do
      expect(cell_html(row_data: { 'fullscreen-btn' => 'on' })['data-fullscreen-btn']).to eq('on')
    end
  end
end

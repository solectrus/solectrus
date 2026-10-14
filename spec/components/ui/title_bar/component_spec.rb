describe Ui::TitleBar::Component, type: :component do
  it 'renders the title without a back button on the top level' do
    html = render_inline(described_class.new(title: 'Settings'))

    expect(html.css('h1').text).to eq('Settings')
    expect(html.css('a')).to be_empty
  end

  it 'hides itself on the desktop' do
    html = render_inline(described_class.new(title: 'Settings'))

    expect(html.at('.ui-title-bar')['class']).to include('lg:hidden')
  end

  it 'renders a back button to the parent' do
    html =
      render_inline(
        described_class.new(
          title: 'General',
          back_href: '/settings',
          back_label: 'Settings',
        ),
      )

    link = html.css('a').first
    expect(link['href']).to eq('/settings')
    expect(link['aria-label']).to eq('Settings')
  end

  it 'slides back to a parent with a title bar only' do
    sliding = render_inline(described_class.new(title: 'General', back_href: '/settings', back_label: 'Settings'))
    expect(sliding.css('a.ui-title-bar-back').first['data-nav-title']).to eq('Settings')

    plain = render_inline(described_class.new(title: 'Sessions', back_href: '/cars', back_label: 'Car', back_slide: false))
    expect(plain.css('a.ui-title-bar-back').first['data-nav-title']).to be_nil
  end

  it 'renders an action as an icon button' do
    html =
      render_inline(described_class.new(title: 'Prices')) do |bar|
        bar.with_action(href: '/new', icon: 'plus', label: 'New price')
      end

    link = html.css('a.ui-title-bar-action').first
    expect(link['href']).to eq('/new')
    expect(link['aria-label']).to eq('New price')
    expect(link.text.strip).to be_empty
  end

  it 'renders the save button of a form outside it, disabled until the form changes' do
    html =
      render_inline(described_class.new(title: 'Edit price')) do |bar|
        bar.with_save(form: 'form_price_1')
      end

    button = html.css('button.ui-title-bar-save').first
    aggregate_failures do
      expect(button['type']).to eq('submit')
      expect(button['form']).to eq('form_price_1')
      expect(button['disabled']).not_to be_nil
      expect(button['data-form-dirty-submit']).not_to be_nil
      expect(button['aria-label']).to eq(I18n.t('crud.save'))
    end
  end
end

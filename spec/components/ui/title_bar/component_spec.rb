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

  it 'shows a logo in place of the title, named by the title' do
    html = render_inline(described_class.new(title: 'More', logo: '/logo.svg'))

    image = html.at('h1 img.ui-title-bar-logo')
    expect(image['src']).to eq('/logo.svg')
    expect(image['alt']).to eq('More')
  end

  it 'names the logo of the parent for the slide back' do
    html = render_inline(described_class.new(title: 'Top 10', back_href: '/more', back_label: 'More', back_logo: '/logo.svg'))

    expect(html.at('a.ui-title-bar-back')['data-nav-logo']).to eq('/logo.svg')
  end

  it 'leaves the background of a plain page alone' do
    plain = render_inline(described_class.new(title: 'Top 10', plain: true))
    expect(plain.at('.ui-title-bar')['class']).to include('ui-title-bar-plain')

    grouped = render_inline(described_class.new(title: 'Settings'))
    expect(grouped.at('.ui-title-bar')['class']).not_to include('ui-title-bar-plain')
  end

  it 'tells a link the logo and the background of the next page' do
    expect(described_class.link_data('More', logo: '/logo.svg', plain: true)).to eq(
      nav_title: 'More', nav_logo: '/logo.svg', nav_plain: true, turbo_prefetch: false,
    )
    expect(described_class.link_data('Settings')).to eq(nav_title: 'Settings', turbo_prefetch: false)
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

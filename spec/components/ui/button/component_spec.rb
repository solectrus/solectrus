describe Ui::Button::Component, type: :component do
  it 'renders a link with its label' do
    render_inline(described_class.new(href: '/login', label: 'Log in', data: { turbo: false }))

    link = page.find('a[href="/login"]', text: 'Log in')
    aggregate_failures do
      expect(link['data-turbo']).to eq('false')
      expect(link[:class]).to include('bg-indigo-600')
    end
  end

  it 'puts the classes of the caller before its look' do
    render_inline(described_class.new(href: '/', label: 'Home', class: 'text-lg'))

    expect(page.find('a')[:class]).to start_with('text-lg')
  end

  it 'renders a button in a form of its own' do
    render_inline(described_class.new(href: '/reset', label: 'Reset', type: :button, method: :delete))

    aggregate_failures do
      expect(page).to have_css('form[action="/reset"] input[name="_method"][value="delete"]', visible: :all)
      expect(page).to have_button('Reset')
    end
  end

  it 'renders a submit button with an icon alone and an HTML title' do
    render_inline(described_class.new(type: :submit, icon: 'trash', style: :secondary, title: 'Delete'))

    button = page.find('button[type="submit"][title="Delete"]')
    aggregate_failures do
      expect(button).to have_css('.fa-trash.w-8')
      expect(button[:class]).to include('hover:scale-125')
      expect(button).to have_no_css('span')
    end
  end

  it 'underlines a secondary label' do
    render_inline(described_class.new(href: '/', label: 'More', style: :secondary))

    expect(page.find('a')[:class]).to include('underline')
  end
end

describe Ui::Popover::Component, type: :component do
  def render_popover(pick: false)
    render_inline(described_class.new(class: 'relative', data: { controller: 'other' })) do |popover|
      popover.with_trigger(class: 'button', data: { controller: 'tooltip' }, 'aria-label': 'Options') { 'Open' }
      popover.with_panel(class: 'panel', pick:) { 'Inside' }
    end
  end

  it 'keeps the controllers of the caller beside its own' do
    render_popover

    aggregate_failures do
      expect(page).to have_css('div.relative[data-controller="ui--popover--component other"]')
      expect(page).to have_css('button.button[data-controller="tooltip"][aria-label="Options"]', text: 'Open')
    end
  end

  it 'renders a closed trigger and a hidden panel' do
    render_popover

    aggregate_failures do
      expect(page).to have_css('button[type="button"][aria-haspopup="true"][aria-expanded="false"]')
      expect(page).to have_css('button[data-action="click->ui--popover--component#toggle"]')
      expect(page).to have_css('div.hidden.panel[data-ui--popover--component-target="panel"]', text: 'Inside', visible: :all)
    end
  end

  it 'closes on a pick only with pick: true' do
    render_popover(pick: true)
    expect(page).to have_css('.panel[data-action="click->ui--popover--component#pick"]', visible: :all)

    render_popover
    expect(page).to have_no_css('.panel[data-action]', visible: :all)
  end
end

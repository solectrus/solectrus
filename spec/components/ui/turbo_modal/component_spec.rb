describe Ui::TurboModal::Component, type: :component do
  it 'renders a sheet in the modal frame for a request of that frame' do
    vc_test_request.headers['Turbo-Frame'] = 'modal'
    render_inline(described_class.new(title: 'Edit price')) { 'The form' }

    aggregate_failures do
      expect(page).to have_css('turbo-frame#modal [data-controller="ui--turbo-modal--component"] dialog', text: 'The form', visible: :all)
      expect(page).to have_css('dialog h1', text: 'Edit price', visible: :all)
    end
  end

  it 'renders a plain page for any other request' do
    render_inline(described_class.new(title: 'Edit price')) { 'The form' }

    aggregate_failures do
      expect(page).to have_no_css('turbo-frame')
      expect(page).to have_css('h1', text: 'Edit price')
      expect(page).to have_text('The form')
    end
  end

  it 'gives the data of a link into the modal' do
    expect(described_class.link_data(tooltip: true, action: 'x#y')).to eq(
      turbo_frame: 'modal', controller: 'tooltip modal-launcher', action: 'x#y',
    )
  end
end

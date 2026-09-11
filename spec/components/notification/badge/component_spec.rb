describe Notification::Badge::Component, type: :component do
  subject(:component) { described_class.new }

  before do
    Notification.create!(
      title: 'Important Message',
      body: '<p>Body</p>',
      published_at: 1.day.ago,
    )
    allow(vc_test_controller).to receive(:admin?).and_return(admin)
  end

  context 'when logged in as admin' do
    let(:admin) { true }

    it 'links to the notification itself' do
      render_inline(component)

      expect(page.find('a')['href']).to eq('/notifications/latest')
    end
  end

  # A guest cannot read notifications, so the badge leads to the list page,
  # which explains why. It is the hint that makes the admin log in on a device
  # where they are not signed in.
  context 'when not logged in' do
    let(:admin) { false }

    it 'links to the list, which explains the login' do
      render_inline(component)

      expect(page.find('a')['href']).to eq('/notifications')
    end

    it 'does not open the modal' do
      render_inline(component)

      expect(page.find('a')['data-turbo-frame']).to eq('_top')
    end
  end
end

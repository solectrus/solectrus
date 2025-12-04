describe 'Notifications' do
  after { Notification.delete_all }

  context 'when not logged in as admin' do
    before do
      Notification.create!(
        title: 'Wichtige Neuigkeit',
        body: '<p>Das ist der Inhalt der Nachricht.</p>',
        published_at: 1.day.ago,
      )
    end

    it 'shows notification badge but cannot access notifications page' do
      visit '/'
      # Badge is shown to all users
      expect(page).to have_css(
        '[id^="notifications-badge"] .bg-red-500',
        text: '1',
      )

      # But the page is protected
      visit '/notifications'
      expect(page).to have_content('ForbiddenError')
    end
  end

  context 'when logged in as admin' do
    let!(:unread_notification) do
      Notification.create!(
        title: 'Wichtige Neuigkeit',
        body: '<p>Das ist der Inhalt der Nachricht.</p>',
        published_at: 1.day.ago,
      )
    end

    before do
      Notification.create!(
        title: 'Alte Nachricht',
        body: '<p>Diese Nachricht wurde bereits gelesen.</p>',
        published_at: 2.days.ago,
        read_at: 1.day.ago,
      )
      login_as_admin
    end

    it 'shows notification badge with unread count' do
      visit '/'
      expect(page).to have_css(
        '[id^="notifications-badge"] .bg-red-500',
        text: '1',
      )
    end

    it 'can view notifications list' do
      visit '/notifications'
      expect(page).to have_content('Benachrichtigungen')
      expect(page).to have_content('Wichtige Neuigkeit')
      expect(page).to have_content('Alte Nachricht')
    end

    it 'can open and mark notification as read' do
      visit '/notifications'

      # Open the unread notification
      first(:link, 'Wichtige Neuigkeit').click

      # Modal should show notification content
      expect(page).to have_content('Das ist der Inhalt der Nachricht.')

      # Click OK to mark as read and close modal
      click_on 'OK'

      # Wait for modal to close
      expect(page).to have_no_content('Das ist der Inhalt der Nachricht.')

      # Notification should now be marked as read
      expect(unread_notification.reload).to be_read
    end

    it 'updates badge when notification is marked as read' do
      visit '/'
      expect(page).to have_css(
        '[id^="notifications-badge"] .bg-red-500',
        text: '1',
      )

      visit '/notifications'
      first(:link, 'Wichtige Neuigkeit').click
      click_on 'OK'

      # Check that modal is closed first (positive assertion)
      expect(page).to have_content('Benachrichtigungen')
      expect(page).to have_no_css('[id^="notifications-badge"] .bg-red-500')
    end
  end
end

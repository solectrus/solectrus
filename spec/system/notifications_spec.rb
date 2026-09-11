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

    it 'shows notification badge but cannot read the notification' do
      visit '/'
      # Badge is shown to all users (look for message icon with red badge)
      expect(page).to have_css('#notification-badge-desktop a', text: '1')

      # The message itself stays protected
      visit "/notifications/#{Notification.first.id}"
      expect(page).to have_text('ForbiddenError')
    end

    # The badge stays visible for guests on purpose: on a public instance it is
    # the only hint that something is waiting, and the admin often browses from
    # a device where they are not signed in. Landing on a forbidden page would
    # never tell them why the red mark does not go away.
    it 'explains why the notification cannot be read' do
      visit '/'
      find('#notification-badge-desktop a').click

      expect(page).to have_text('Hier erscheinen Neuigkeiten zu SOLECTRUS.')
      expect(page).to have_text('bleibt die rote Markierung stehen')
      expect(page).to have_css('#notification-unread-count', text: '1')
      expect(page).to have_no_text('Das ist der Inhalt der Nachricht.')
    end

    # A count of zero would be an odd thing to show, so the red mark on the icon
    # appears only while something is actually unread.
    context 'when everything is read' do
      before { Notification.find_each(&:mark_as_read!) }

      it 'explains the page without showing a count' do
        visit '/notifications'

        expect(page).to have_text('Hier erscheinen Neuigkeiten zu SOLECTRUS.')
        expect(page).to have_no_css('#notification-unread-count')
        expect(page).to have_no_text('bleibt die rote Markierung stehen')
      end
    end

    it 'leads from the explanation to the login and back' do
      visit '/notifications'
      click_on 'Als Admin anmelden'

      expect(page).to have_field('admin_user_password')
      expect(page).to have_field('return_to', with: '/notifications', type: :hidden)
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
      expect(page).to have_css('#notification-badge-desktop a', text: '1')
    end

    it 'can view notifications list' do
      visit '/notifications'
      expect(page).to have_text('Benachrichtigungen')
      expect(page).to have_text('Wichtige Neuigkeit')
      expect(page).to have_text('Alte Nachricht')
    end

    it 'can open and mark notification as read' do
      visit '/notifications'

      # Open the unread notification
      first(:link, 'Wichtige Neuigkeit').click

      # Modal should be open
      expect(page).to have_css('dialog[open]')

      # Click the button to mark as read and close modal
      click_on 'Verstanden'

      # Wait for modal to close
      expect(page).to have_no_css('dialog[open]')

      # The modal closes client-side on click, but the PATCH that marks the
      # notification as read is a separate round-trip. Wait for its Turbo Stream
      # effect - the unread badge disappears (it renders only while unread) -
      # before checking the persisted state, otherwise we race the still
      # in-flight request.
      expect(page).to have_no_css('#notification-badge-desktop a')

      # Notification should now be marked as read
      expect(unread_notification.reload).to be_read
    end

    it 'updates badge when notification is marked as read' do
      visit '/'
      expect(page).to have_css('#notification-badge-desktop a', text: '1')

      visit '/notifications'
      first(:link, 'Wichtige Neuigkeit').click
      click_on 'Verstanden'

      # Check that modal is closed first (positive assertion)
      expect(page).to have_text('Benachrichtigungen')
      expect(page).to have_no_css('#notification-badge-desktop a')
    end
  end
end

describe UpdateCheck::NotificationImporter do
  describe '#call' do
    subject(:call) { described_class.new(notifications_data).call }

    context 'when notifications_data is nil' do
      let(:notifications_data) { nil }

      it 'does not create any notifications' do
        expect { call }.not_to change(Notification, :count)
      end
    end

    context 'when notifications_data is empty' do
      let(:notifications_data) { [] }

      it 'does not create any notifications' do
        expect { call }.not_to change(Notification, :count)
      end
    end

    context 'when notifications_data contains valid notifications' do
      let(:notifications_data) do
        [
          {
            id: 1,
            title: 'First notification',
            body: 'This is the first notification body.',
            published_at: '2024-01-15T10:00:00Z',
          },
          {
            id: 2,
            title: 'Second notification',
            body: 'This is the second notification body.',
            published_at: '2024-01-16T12:00:00Z',
          },
        ]
      end

      it 'creates all notifications' do
        expect { call }.to change(Notification, :count).by(2)
      end

      it 'sets the correct attributes' do
        call

        notification = Notification.find(1)
        expect(notification.title).to eq('First notification')
        expect(notification.body).to eq('This is the first notification body.')
        expect(notification.published_at).to eq(
          Time.zone.parse('2024-01-15T10:00:00Z'),
        )
        expect(notification.read_at).to be_nil
      end
    end

    context 'when a notification already exists' do
      let(:notifications_data) do
        [
          {
            id: 1,
            title: 'Updated title',
            body: 'Updated body',
            published_at: '2024-01-15T10:00:00Z',
          },
        ]
      end

      before do
        Notification.create!(
          id: 1,
          title: 'Original title',
          body: 'Original body',
          published_at: '2024-01-14T10:00:00Z',
        )
      end

      it 'does not create a duplicate' do
        expect { call }.not_to change(Notification, :count)
      end

      it 'updates the existing notification' do
        call

        notification = Notification.find(1)
        expect(notification.title).to eq('Updated title')
        expect(notification.body).to eq('Updated body')
      end

      it 'preserves read_at when updating' do
        Notification.find(1).update!(read_at: 1.hour.ago)
        original_read_at = Notification.find(1).read_at

        call

        notification = Notification.find(1)
        expect(notification.read_at).to eq(original_read_at)
      end
    end

    context 'when notification data is missing required fields' do
      context 'when id is missing' do
        let(:notifications_data) do
          [
            {
              title: 'Title',
              body: 'Body',
              published_at: '2024-01-15T10:00:00Z',
            },
          ]
        end

        it 'does not create the notification' do
          expect { call }.not_to change(Notification, :count)
        end
      end

      context 'when title is missing' do
        let(:notifications_data) do
          [{ id: 1, body: 'Body', published_at: '2024-01-15T10:00:00Z' }]
        end

        it 'does not create the notification' do
          expect { call }.not_to change(Notification, :count)
        end
      end

      context 'when body is missing' do
        let(:notifications_data) do
          [{ id: 1, title: 'Title', published_at: '2024-01-15T10:00:00Z' }]
        end

        it 'does not create the notification' do
          expect { call }.not_to change(Notification, :count)
        end
      end

      context 'when title is blank' do
        let(:notifications_data) do
          [
            {
              id: 1,
              title: '',
              body: 'Body',
              published_at: '2024-01-15T10:00:00Z',
            },
          ]
        end

        it 'does not create the notification' do
          expect { call }.not_to change(Notification, :count)
        end
      end
    end

    context 'when notification data has invalid published_at' do
      let(:notifications_data) do
        [{ id: 1, title: 'Title', body: 'Body', published_at: 'invalid-date' }]
      end

      it 'does not create the notification' do
        expect { call }.not_to change(Notification, :count)
      end

      it 'logs a warning' do
        allow(Rails.logger).to receive(:warn)
        call
        expect(Rails.logger).to have_received(:warn).with(
          /Skipping invalid notification data:.*invalid-date/,
        )
      end
    end

    context 'when notification data is invalid' do
      let(:notifications_data) do
        [
          {
            id: nil,
            title: nil,
            body: nil,
            published_at: '2024-01-15T10:00:00Z',
          },
        ]
      end

      it 'logs a warning' do
        allow(Rails.logger).to receive(:warn)
        call
        expect(Rails.logger).to have_received(:warn).with(
          /Skipping invalid notification data/,
        )
      end
    end

    context 'when database error occurs' do
      let(:notifications_data) do
        [
          {
            id: 1,
            title: 'Title',
            body: 'Body',
            published_at: '2024-01-15T10:00:00Z',
          },
        ]
      end

      it 'logs a warning and does not raise' do
        allow(Notification).to receive(:upsert_all).and_raise(
          ActiveRecord::StatementInvalid.new('DB error'),
        )
        allow(Rails.logger).to receive(:warn)

        expect { call }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with(
          /Failed to import notifications/,
        )
      end
    end
  end
end

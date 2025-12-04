# == Schema Information
#
# Table name: notifications
#
#  id           :bigint           not null, primary key
#  body         :text             not null
#  published_at :datetime         not null
#  read_at      :datetime
#  title        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_notifications_on_published_at  (published_at)
#  index_notifications_on_unread        (id) WHERE (read_at IS NULL)
#
describe Notification do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:published_at) }
  end

  describe 'scopes' do
    let!(:unread_notification) do
      described_class.create!(
        title: 'Unread',
        body: 'Body',
        published_at: 1.day.ago,
      )
    end

    let!(:read_notification) do
      described_class.create!(
        title: 'Read',
        body: 'Body',
        published_at: 2.days.ago,
        read_at: 1.hour.ago,
      )
    end

    describe '.unread' do
      subject { described_class.unread }

      it { is_expected.to contain_exactly(unread_notification) }
    end

    describe '.read' do
      subject { described_class.read }

      it { is_expected.to contain_exactly(read_notification) }
    end

    describe '.by_published_at' do
      subject { described_class.by_published_at }

      it { is_expected.to eq([unread_notification, read_notification]) }
    end
  end

  describe '.stats' do
    subject(:stats) { described_class.stats }

    context 'when no notifications exist' do
      it { is_expected.to eq([false, 0]) }
    end

    context 'when only read notifications exist' do
      before do
        described_class.create!(
          title: 'Read',
          body: 'Body',
          published_at: 1.day.ago,
          read_at: 1.hour.ago,
        )
      end

      it { is_expected.to eq([true, 0]) }
    end

    context 'when unread notifications exist' do
      before do
        described_class.create!(
          title: 'Unread',
          body: 'Body',
          published_at: 1.day.ago,
        )
        described_class.create!(
          title: 'Read',
          body: 'Body',
          published_at: 2.days.ago,
          read_at: 1.hour.ago,
        )
      end

      it { is_expected.to eq([true, 1]) }
    end
  end

  describe '#mark_as_read!' do
    let(:notification) do
      described_class.create!(
        title: 'Test',
        body: 'Body',
        published_at: Time.current,
        read_at: nil,
      )
    end

    it 'sets read_at to current time' do
      freeze_time do
        expect { notification.mark_as_read! }.to change(
          notification,
          :read_at,
        ).from(nil).to(Time.current)
      end
    end

    it 'does not update if already read' do
      notification.update!(read_at: 1.hour.ago)
      original_read_at = notification.read_at

      expect { notification.mark_as_read! }.not_to change(
        notification,
        :read_at,
      ).from(original_read_at)
    end
  end

  describe 'broadcasting' do
    describe 'on create' do
      it 'broadcasts to notifications stream' do
        expect do
          described_class.create!(
            title: 'New',
            body: 'Body',
            published_at: Time.current,
          )
        end.to have_broadcasted_to('notifications').at_least(:once)
      end
    end

    describe 'on update' do
      let!(:notification) do
        described_class.create!(
          title: 'Test',
          body: 'Body',
          published_at: Time.current,
        )
      end

      it 'broadcasts to notifications stream' do
        expect do
          notification.update!(title: 'Updated')
        end.to have_broadcasted_to('notifications').at_least(:once)
      end
    end

    describe 'on mark_as_read!' do
      let!(:notification) do
        described_class.create!(
          title: 'Test',
          body: 'Body',
          published_at: Time.current,
        )
      end

      it 'broadcasts to notifications stream' do
        expect { notification.mark_as_read! }.to have_broadcasted_to(
          'notifications',
        ).at_least(:once)
      end
    end
  end

  describe 'constants' do
    it 'defines BADGE_IDS' do
      expect(described_class::BADGE_IDS).to eq(
        [described_class::BADGE_ID_DESKTOP, described_class::BADGE_ID_MOBILE],
      )
    end

    it 'has consistent badge IDs' do
      expect(described_class::BADGE_ID_DESKTOP).to eq(
        'notifications-badge-desktop',
      )
      expect(described_class::BADGE_ID_MOBILE).to eq(
        'notifications-badge-mobile',
      )
    end
  end
end

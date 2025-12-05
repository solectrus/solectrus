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
class Notification < ApplicationRecord
  validates :title, presence: true
  validates :body, presence: true
  validates :published_at, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :by_published_at, -> { order(published_at: :desc) }

  after_commit :invalidate_stats_cache

  def self.stats
    Rails
      .cache
      .fetch('notification_stats', expires_in: 1.minute) do
        pick(
          Arel.sql('EXISTS(SELECT 1 FROM notifications)'),
          Arel.sql('COUNT(*) FILTER (WHERE read_at IS NULL)'),
        )
      end
  end

  def read?
    read_at?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    return unless unread?

    self.read_at = Time.current
    save!(touch: false)
  end

  private

  def invalidate_stats_cache
    Rails.cache.delete('notification_stats')
  end
end

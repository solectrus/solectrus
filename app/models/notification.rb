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
  include Turbo::Broadcastable

  BADGE_ID_DESKTOP = 'notifications-badge-desktop'.freeze
  BADGE_ID_MOBILE = 'notifications-badge-mobile'.freeze
  BADGE_IDS = [BADGE_ID_DESKTOP, BADGE_ID_MOBILE].freeze
  public_constant :BADGE_ID_DESKTOP, :BADGE_ID_MOBILE, :BADGE_IDS

  validates :title, presence: true
  validates :body, presence: true
  validates :published_at, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :by_published_at, -> { order(published_at: :desc) }

  after_commit :invalidate_stats_cache
  after_commit :broadcast_changes, on: %i[create update]

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

  def broadcast_changes
    broadcast_badges
    broadcast_item
  end

  def broadcast_badges
    BADGE_IDS.each do |target|
      broadcast_replace_to(
        'notifications',
        target:,
        html: render_component(Notification::Badge::Component.new(id: target)),
      )
    end
  end

  def invalidate_stats_cache
    Rails.cache.delete('notification_stats')
  end

  def broadcast_item
    broadcast_replace_to(
      'notifications',
      target: self,
      html:
        render_component(Notification::Item::Component.new(notification: self)),
    )
  end

  def render_component(component)
    ApplicationController.render(component, layout: false)
  end
end

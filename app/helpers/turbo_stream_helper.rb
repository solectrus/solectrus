module TurboStreamHelper
  def turbo_stream_update_navigation
    safe_join(
      [
        turbo_stream_update_primary_nav,
        turbo_stream_update_second_nav,
        turbo_stream_update_timeframe,
      ],
    )
  end

  private

  def turbo_stream_update_primary_nav
    # Without the root item, which is the logo (see Nav::Top::Component).
    items =
      desktop_primary_items.drop(1).map { MenuItem::Component.new(**it) }

    turbo_stream.update('primary-nav-desktop') do
      render Nav::Top::Component::ItemsComponent.new(items:)
    end
  end

  def turbo_stream_update_second_nav
    turbo_stream.update(frame_id('second-nav')) do
      render Nav::Sub::Component.new do |c|
        c.with_items nav_items
      end
    end
  end

  def turbo_stream_update_notification_indicators
    safe_join(
      [
        turbo_stream.update('notification-badge-desktop') do
          render Notification::Badge::Component.new(unread_count: unread_notifications_count)
        end,
        turbo_stream.update('bottom-nav-notification-dot') do
          render Notification::Dot::Component.new(unread_count: unread_notifications_count)
        end,
      ],
    )
  end

  def turbo_stream_update_timeframe
    turbo_stream.update(frame_id('timeframe')) do
      render Timeframe::Component.new(timeframe:)
    end
  end
end

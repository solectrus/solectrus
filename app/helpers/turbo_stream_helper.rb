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
    component = Nav::Top::Component.new
    component.with_primary_items(desktop_primary_items)

    turbo_stream.update('primary-nav-desktop') do
      render Nav::Top::Component::Items.new(
               items: component.primary_items_without_root,
             )
    end
  end

  def turbo_stream_update_second_nav
    turbo_stream.update(frame_id('second-nav')) do
      render Nav::Sub::Component.new do |c|
        c.with_items nav_items
      end
    end
  end

  def turbo_stream_update_notification_badge
    content = render Notification::Badge::Component.new

    safe_join(
      %i[desktop mobile].map do |device|
        turbo_stream.update("notification-badge-#{device}") { content }
      end,
    )
  end

  def turbo_stream_update_timeframe
    turbo_stream.update(frame_id('timeframe')) do
      render Timeframe::Component.new(timeframe:)
    end
  end
end

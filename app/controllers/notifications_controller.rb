class NotificationsController < ApplicationController
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  # Reading a notification and marking it as read stay with the admin. The list
  # page is the one exception: a guest who followed the red mark lands here and
  # is told why they see nothing and why the mark does not go away.
  before_action :admin_required!, except: :index

  rescue_from ActiveRecord::RecordNotFound, with: :redirect_to_index

  def index
    redirect_to root_path unless Notification.any_notifications?
  end

  def show
    render Notification::Show::Component.new(notification:)
  end

  def latest
    @notification = Notification.unread.by_published_at.first
    if @notification
      render Notification::Show::Component.new(notification: @notification)
    else
      redirect_to notifications_path
    end
  end

  def mark_as_read
    notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to(root_path) }
    end
  end

  private

  helper_method def notifications
    @notifications ||= Notification.by_published_at.select(:id, :title, :published_at, :read_at).load
  end

  helper_method def notification
    @notification ||= Notification.find(params.expect(:id))
  end

  helper_method def title
    t('layout.notifications')
  end

  def redirect_to_index
    redirect_to notifications_path
  end
end

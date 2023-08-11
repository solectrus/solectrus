module ApplicationHelper
  def registration_banner?
    Rails.configuration.x.registration_required &&
      UpdateCheck.instance.registration_status.in?(%w[unregistered pending])
  end
end

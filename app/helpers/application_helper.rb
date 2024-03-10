module ApplicationHelper
  def registration_banner?
    UpdateCheck.instance.registration_status.in?(%w[unregistered pending])
  end
end

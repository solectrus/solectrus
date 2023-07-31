class RegistrationController < ApplicationController
  def show
    if admin? && Rails.configuration.x.registration_required
      if status_present?
        Version.clear_cache
        redirect_to(root_path)
      else
        redirect_to(registration_url, allow_other_host: true)
      end
    else
      redirect_to(root_path)
    end
  end

  private

  def registration_url
    "https://registration.solectrus.de/?id=#{magic_id}&return_to=#{return_to}"
  end

  def magic_id
    MagicId.new.encode(UserAgent.instance.setup_id)
  end

  def return_to
    Base64.urlsafe_encode64 "#{request.protocol}#{request.host_with_port}",
                            padding: false
  end

  def status_present?
    params[:status].present?
  end
end

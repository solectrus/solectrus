class RegistrationController < ApplicationController
  def show
    if admin?
      case params[:status]
      when nil
        redirect_to(registration_url, allow_other_host: true)
      when 'skipped'
        UpdateCheck.instance.skip_registration
        redirect_back(fallback_location: root_path)
      else
        UpdateCheck.instance.clear_cache
        redirect_to(root_path)
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
    MagicId.new.encode(Setting.setup_id, Setting.setup_token)
  end

  def return_to
    Base64.urlsafe_encode64 "#{request.protocol}#{request.host_with_port}",
                            padding: false
  end
end

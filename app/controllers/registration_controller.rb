class RegistrationController < ApplicationController
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  def show
    if admin?
      case params[:status]
      when nil
        redirect_to(registration_url, allow_other_host: true)
      when 'skip'
        UpdateCheck.skip_prompt!

        redirect_to(root_path)
      else
        UpdateCheck.clear_cache!
        redirect_to(root_path)
      end
    else
      redirect_to(root_path)
    end
  end

  private

  def registration_domain
    if Rails.env.development?
      # :nocov:
      'registration.solectrus.test'
      # :nocov:
    else
      'registration.solectrus.de'
    end
  end

  def registration_url
    "https://#{registration_domain}/?id=#{magic_id}&return_to=#{return_to}"
  end

  def magic_id
    MagicId.new.encode(Setting.setup_id, Setting.setup_token)
  end

  def return_to
    Base64.urlsafe_encode64 "#{request.protocol}#{request.host_with_port}",
                            padding: false
  end
end

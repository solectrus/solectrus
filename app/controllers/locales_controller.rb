class LocalesController < ApplicationController
  # Switching the language must work even while a registration/sponsoring
  # redirect would otherwise kick in.
  skip_before_action :check_for_registration
  skip_before_action :check_for_sponsoring

  def update
    locale = params[:locale].to_s.to_sym

    # Not signed/encrypted on purpose: the value is a public locale code and
    # is validated against available_locales on every request anyway.
    if I18n.available_locales.include?(locale)
      cookies.permanent[:locale] = {
        value: locale,
        httponly: true,
        secure: request.ssl?,
        same_site: :lax,
      }
    end

    redirect_back_or_to root_path, status: :see_other
  end
end

class ErrorsController < ApplicationController
  skip_before_action :check_for_sponsoring

  def show
    if turbo_frame_request?
      render 'turbo_frame', status: status_code, formats: [:html], layout: false
    else
      render 'show', status: status_code, formats: [:html]
    end
  end

  private

  helper_method def title
    t('errors.title')
  end

  helper_method def status_code
    @status_code ||=
      begin
        exception = request.env['action_dispatch.exception']

        exception.try(:status_code) ||
          ActionDispatch::ExceptionWrapper.new(
            request.env,
            exception,
          ).status_code
      end
  end
end

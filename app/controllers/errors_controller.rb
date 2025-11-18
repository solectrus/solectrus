class ErrorsController < ApplicationController
  skip_before_action :check_for_sponsoring

  def show
    if turbo_frame_request?
      if modal_frame?
        # For modal frame requests, show error in modal
        render 'modal', status: status_code, formats: [:html], layout: false
      else
        # For other frame requests, replace entire content
        render 'stream', status: status_code, formats: [:turbo_stream]
      end
    else
      # For regular requests, show full page error
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

  def modal_frame?
    request.headers['Turbo-Frame'] == 'modal'
  end
end

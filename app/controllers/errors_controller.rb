class ErrorsController < ApplicationController
  skip_before_action :check_for_sponsoring

  def show
    render 'show', status: status_code, formats: [:html]
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

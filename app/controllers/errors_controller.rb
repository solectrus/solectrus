class ErrorsController < ApplicationController
  def show
    render 'show', status: status_code, formats: [:html]
  end

  private

  helper_method def title
    t('errors.title')
  end

  helper_method def description
    if exception_wrapper.message == exception.class.to_s
      t("errors.#{status_code}.description")
    else
      exception_wrapper.message
    end
  end

  helper_method def status_code
    @status_code ||=
      exception.try(:status_code) || exception_wrapper.status_code
  end

  def exception_wrapper
    @exception_wrapper ||=
      ActionDispatch::ExceptionWrapper.new(request.env, exception)
  end

  def exception
    @exception ||= request.env['action_dispatch.exception']
  end
end

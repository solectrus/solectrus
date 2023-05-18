class ErrorsController < ApplicationController
  def show
    exception = request.env['action_dispatch.exception']
    @status_code =
      exception.try(:status_code) ||
        ActionDispatch::ExceptionWrapper.new(request.env, exception).status_code

    render 'show', status: @status_code, formats: [:html]
  end
end

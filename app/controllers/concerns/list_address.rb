# The address of a list as the browser shows it. A link to the form of an
# entry passes it as return_to, and the way back from the form leads to this
# very address. So the way back finds the list in the history (see
# setupBackTo.ts), with whatever filter or timeframe the address has, and no
# list has to build its own address again.
module ListAddress
  extend ActiveSupport::Concern

  included do
    helper_method :list_address
  end

  private

  # A next page of the list loads into a frame of its own (see
  # LazyRows::Component). Its address has the page, which the list does not.
  def list_address
    query = request.query_parameters.except('page')
    query.empty? ? request.path : "#{request.path}?#{query.to_query}"
  end
end

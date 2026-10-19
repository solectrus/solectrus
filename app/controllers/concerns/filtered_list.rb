# A list with a filter (see ListFilter). Its links set the filter in the
# query of the list. The index remembers the filter in the session, and
# a form takes the filter of the list that opened it, from its address,
# or the filter that the list showed last. So a save renders the list with
# its filter (see FormPageResponse).
#
# The controller names the class of the filter. A filter with members of
# its own gets what they need from `filter_context`:
#
#   filters_with CashFlow::Filter
module FilteredList
  extend ActiveSupport::Concern

  included do
    helper_method :filter, :filter_path
    after_action :remember_filter, if: -> { action_name == 'index' }
  end

  class_methods do
    def filters_with(filter_class)
      define_method(:filter_class) { filter_class }
      private :filter_class
    end
  end

  private

  def filter
    @filter ||= filter_class.from_params(filter_source, **filter_context)
  end

  # The address of the list with another filter, like a narrower one
  def filter_path(other = filter) = url_for(controller: "/#{controller_path}", action: :index, only_path: true, **other.to_params)

  # What the filter needs besides the query, for the members of its own
  def filter_context = {}

  # A form carries no filter, so it takes the one of the list that opened it
  def filter_source
    return request.query_parameters unless action_name.in?(%w[new create update destroy])

    return_to ? return_to_params(controller_path) : remembered_filter
  end

  def remember_filter = (session[filter_session_key] = filter.to_params)

  def remembered_filter = session[filter_session_key].to_h

  def filter_session_key = :"#{controller_name}_filter"

  # The list with the filter it showed last, for a form that no list opened
  def default_list_path = filter_path(filter_class.from_params(remembered_filter, **filter_context))
end

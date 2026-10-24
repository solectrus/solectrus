# The timeframe select loads the address of the page into the modal, with the
# parameter `select` (see .path), and the page answers with the select instead
# of itself.
module TimeframeSelectModal
  extend ActiveSupport::Concern

  PARAM = 'select'.freeze
  public_constant :PARAM

  # The address that opens the timeframe select of the page at `href`
  def self.path(href)
    uri = URI(href)
    uri.query = [uri.query, "#{PARAM}=1"].compact.join('&')
    uri.to_s
  end

  included do
    before_action(only: :index, if: :timeframe_select?) { render timeframe_select_template }
    helper_method :year_comparison_items
  end

  private

  def timeframe_select? = turbo_frame_request_id == 'modal' && params.key?(PARAM)

  def timeframe_select_template = 'timeframe_select/index'

  # A home page offers the comparisons of the years (see TimeframeSegments), a
  # list has none
  def year_comparison_items = []
end

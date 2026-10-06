# The timeframe select loads the address of the page into the modal (see
# TimeframePage), and the page answers with the select instead of itself
module TimeframeSelectModal
  extend ActiveSupport::Concern

  included do
    before_action(only: :index, if: -> { turbo_frame_request_id == 'modal' }) { render 'timeframe_select/index' }
  end
end

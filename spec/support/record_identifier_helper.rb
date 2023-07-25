module RecordIdentifierHelper
  include ActionView::RecordIdentifier

  def css_id(*)
    "##{dom_id(*)}"
  end
end

RSpec.configure do |config|
  config.include RecordIdentifierHelper, type: :system
end

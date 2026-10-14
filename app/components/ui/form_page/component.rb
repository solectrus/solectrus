# The form of one entry of a list, like a price, in one of two places. The
# desktop asks for it from the modal frame and shows it in a sheet of the
# given width. A phone opens it on a page of its own, one level below the
# list, whose Ui::TitleBar::Component leads back.
#
# FormPageHelper gives the form what differs between the two places, and the
# controller answers with FormPageResponse.
#
#   = render Ui::FormPage::Component.new(title: 'Edit price') do
#     = render 'form', price:
class Ui::FormPage::Component < ViewComponent::Base
  def initialize(title:, width: :wide)
    super()
    @title = title
    @width = width
  end

  attr_reader :title, :width
end

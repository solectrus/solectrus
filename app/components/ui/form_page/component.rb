# The form of one entry of a list, like a price, in one of three places. The
# desktop asks for it from the modal frame and shows it in a sheet of the
# given width. A phone asks for it from the modal frame too and shows it in a
# tall sheet, whose head holds the save button of the `form` (see
# FormPageHelper#form_sheet?). Without a frame, it is a page of its own, one
# level below the list, whose Ui::TitleBar::Component leads back.
#
# A `subtitle`, like the address of a place, stands below the title in the
# head of the sheet. The modal and the page show it in place of the title.
#
# FormPageHelper gives the form what differs between the places, and the
# controller answers with FormPageResponse.
#
#   = render Ui::FormPage::Component.new(title: 'Edit price', form: form_page_id(price)) do
#     = render 'form', price:
class Ui::FormPage::Component < ViewComponent::Base
  # The parameter of a phone that asks for the form in a sheet
  SHEET_PARAM = :form_sheet
  public_constant :SHEET_PARAM

  # The address that opens the form at `href` in the sheet of a phone
  def self.sheet_path(href)
    uri = URI(href)
    uri.query = [uri.query, "#{SHEET_PARAM}=1"].compact.join('&')
    uri.to_s
  end

  def initialize(title:, subtitle: nil, width: :wide, form: nil)
    super()
    @title = title
    @subtitle = subtitle
    @width = width
    @form = form
  end

  attr_reader :title, :subtitle, :width, :form

  def heading = subtitle || title
end

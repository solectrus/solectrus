# A page for a message, like an error page or a hint to log in: a symbol, a
# title, a text and a footer for the buttons, each a slot. All slots are
# optional.
#
#   = render Ui::Message::Component.new do |c|
#     - c.with_title { 'Not found' }
#     - c.with_footer { render Ui::Button::Component.new(href: root_path, label: 'Home') }
class Ui::Message::Component < ViewComponent::Base
  # A large, pale symbol behind the text, for decoration.
  renders_one :watermark

  # A symbol above the title, at its own size, in the flow of the text. Use it
  # when the symbol carries something the reader must see, such as a count.
  renders_one :icon

  renders_one :header
  renders_one :title
  renders_one :body
  renders_one :footer
end

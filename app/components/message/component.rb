class Message::Component < ViewComponent::Base
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

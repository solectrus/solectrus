class Message::Component < ViewComponent::Base
  renders_one :header
  renders_one :title
  renders_one :body
  renders_one :footer
end

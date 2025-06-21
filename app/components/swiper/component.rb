class Swiper::Component < ViewComponent::Base
  renders_many :pages

  def initialize(key: 'scrollable')
    super
    @key = key
  end
end

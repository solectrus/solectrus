# A note for a guest that the page leaves out the days that only the admin
# sees (see Car::AdminOnlyDays), with the login. It stands out, so someone who
# only forgot to log in sees at once why the latest days are missing. A
# `banner` has no corners, so the page can lay it across its full width.
class Car::AdminOnlyNotice::Component < ViewComponent::Base
  def initialize(text:, banner: false)
    super()
    @text = text
    @banner = banner
  end

  attr_reader :text

  def login_path = helpers.new_session_path(return_to: helpers.request.fullpath)

  def classes
    class_names(
      'grid grid-cols-[auto_1fr] items-center gap-x-3 gap-y-1 bg-amber-100 p-4 text-sm text-attention-strong lg:flex dark:bg-amber-400/10 dark:text-amber-300',
      @banner ? 'sm:px-6 border-y border-amber-200 dark:border-amber-400/20' : 'rounded-lg',
    )
  end
end

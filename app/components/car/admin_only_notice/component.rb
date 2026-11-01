# A note for a visitor that the page leaves out the days that only the admin
# sees (see Car::AdminOnlyDays), with the login. It stands out, so someone who
# only forgot to log in sees at once why the latest days are missing. On the
# desktop a `banner` has no corners, so the page can lay it across its full
# width. A phone keeps the corners and the margin of the card.
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
      'flex items-center gap-3 rounded-lg border border-amber-200 bg-amber-100 px-3 py-2.5 text-sm text-attention-strong dark:border-amber-400/20 dark:bg-amber-400/10 dark:text-amber-300',
      @banner && 'lg:rounded-none lg:border-x-0 lg:px-6 lg:py-4',
    )
  end
end

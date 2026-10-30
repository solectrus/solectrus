# The header of a section of a page, like the access for AI on the system
# page. The desktop shows the title over a line, a phone shows it as the
# header of a grouped list. Other options become attributes of the header,
# and `class:` adds to its classes, like the spacing of the caller.
#
#   = render Ui::SectionHeader::Component.new(title: 'Access for AI', class: 'mb-4 max-lg:mb-0')
class Ui::SectionHeader::Component < ViewComponent::Base
  BASE =
    'border-b border-gray-500 pb-1 font-medium ' \
    'max-lg:border-0 max-lg:px-4 max-lg:pb-1.5 max-lg:text-xs max-lg:uppercase max-lg:tracking-wide max-lg:text-muted'.freeze
  private_constant :BASE

  def initialize(title:, **options)
    super()
    @title = title
    @options = options
  end

  def call = tag.h2(@title, **@options, class: [BASE, @options[:class]])
end

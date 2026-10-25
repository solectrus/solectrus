# A link, a button or a submit button with a label, an icon or both.
#
# `type` picks the element: `:link` (link_to), `:button` (button_to, a form
# of its own, like a delete) or `:submit` (a submit button of the form around
# it). `style` picks the look: `:primary` is filled, `:secondary` is an
# underlined text or a bare icon that grows on hover, and `:tertiary` has no
# look of its own. Every other option goes to the element, like `data:`,
# `method:` or `title:`. Its `class:` stands before the classes of the look.
#
#   = render Ui::Button::Component.new(href: login_path, label: 'Log in')
#   = render Ui::Button::Component.new(type: :submit, icon: 'trash', style: :secondary, title: 'Delete')
class Ui::Button::Component < ViewComponent::Base
  HELPERS = { link: :link_to, button: :button_to, submit: :button_tag }.freeze
  private_constant :HELPERS

  BASE_CLASS = %w[
    inline-flex
    items-center
    relative
    touch-target
    py-1
    md:py-2
    border
    border-transparent
    rounded
    cursor-pointer
    disabled:cursor-default
  ].freeze
  private_constant :BASE_CLASS

  FOCUS_CLASS = %w[
    focus:outline-hidden
    focus:ring-2
    focus:ring-offset-2
    focus:ring-indigo-500
    dark:focus:ring-offset-slate-800
    click-animation
  ].freeze
  private_constant :FOCUS_CLASS

  PRIMARY_CLASS = %w[
    text-white
    dark:text-gray-300
    bg-indigo-600
    dark:bg-indigo-800
    hover:bg-indigo-700
    shadow-sm
    px-3
    hover:scale-105
  ].freeze
  private_constant :PRIMARY_CLASS

  def initialize(href: nil, label: nil, icon: nil, type: :link, style: :primary, **html_options)
    super()

    if label.nil? && icon.nil?
      # simplecov:disable
      raise ArgumentError, 'You must provide either a label or an icon (or both)'
      # simplecov:enable
    end

    @href = href
    @label = label
    @icon = icon
    @tag_helper = HELPERS.fetch(type) do
      # simplecov:disable
      raise ArgumentError, 'Type must be :link, :button or :submit'
      # simplecov:enable
    end
    @style = style
    @html_options = html_options
  end

  def call
    public_send(@tag_helper, @href, @html_options.merge(class: [@html_options[:class], ('gap-2' if @icon && @label), *look_class])) do
      safe_join([(icon(@icon, class: ('w-8' unless @label)) if @icon), (tag.span(@label) if @label)].compact)
    end
  end

  private

  def look_class
    case @style
    when :primary then BASE_CLASS + PRIMARY_CLASS + FOCUS_CLASS
    when :secondary then (@icon ? %w[hover:scale-125] + FOCUS_CLASS : %w[underline underline-offset-4]) + BASE_CLASS
    else BASE_CLASS
    end
  end
end

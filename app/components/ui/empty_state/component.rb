# The place of a list, a map or a chart without content: an icon in a circle,
# a title and an optional text below it. With `slashed: true`, the icon is
# crossed out, for a state that is normal, like a day without a drive. A
# chart takes `size: :small`, so the note does not outweigh the cards beside
# it. The content of the block comes last, for example a link to the settings.
class Ui::EmptyState::Component < ViewComponent::Base
  SIZES = {
    large: {
      root: 'gap-3 md:gap-4',
      circle: 'mb-2 size-24 md:size-32',
      icon: 'text-5xl md:text-6xl',
      title: 'text-xl font-semibold md:text-2xl',
      text: 'text-base md:text-lg',
    },
    small: {
      root: 'gap-2 md:gap-3',
      circle: 'mb-1 size-16 md:size-20',
      icon: 'text-3xl md:text-4xl',
      title: 'text-base font-medium md:text-lg',
      text: 'text-sm md:text-base',
    },
  }.freeze
  private_constant :SIZES

  def initialize(icon:, title:, text: nil, slashed: false, size: :large)
    super()
    @icon_name = icon
    @title = title
    @text = text
    @slashed = slashed
    @size = size
  end

  attr_reader :icon_name, :title, :text

  def slashed? = @slashed

  def classes(part) = SIZES[@size][part]
end

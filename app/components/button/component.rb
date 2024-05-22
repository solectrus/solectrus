class Button::Component < ViewComponent::Base
  def initialize(
    path: nil,
    title: nil,
    icon: nil,
    type: nil,
    style: nil,
    options: {}
  )
    super

    if title.nil? && icon.nil?
      # :nocov:
      raise ArgumentError,
            'You must provide either a title or an icon (or both)'
      # :nocov:
    end

    @path = path
    @title = title
    @icon = icon
    @type = type || :link
    @style = style || :primary
    @options = options
  end

  attr_reader :path, :title, :icon, :style, :options

  def method
    case @type
    when :link
      :link_to
    when :button
      :button_to
    when :submit
      :button_tag
    else
      # :nocov:
      raise ArgumentError, 'Type must be :link, :button or :submit'
      # :nocov:
    end
  end

  def btn_class
    %w[
      inline-flex
      items-center
      py-1
      md:py-2
      border
      border-transparent
      rounded
      focus:outline-none
      focus:ring-2
      focus:ring-offset-2
      focus:ring-indigo-500
      click-animation
    ] +
      case style
      when :primary
        btn_primary_class
      when :secondary
        btn_secondary_class
      when :tertiary
        btn_tertiary_class
      end
  end

  def btn_primary_class
    %w[
      text-white
      bg-indigo-600
      hover:bg-indigo-700
      shadow-sm
      px-3
      hover:scale-105
    ]
  end

  def btn_secondary_class
    ['hover:scale-125']
  end

  def btn_tertiary_class
    []
  end

  def icon_name
    icon.is_a?(Hash) ? icon.fetch(:name) : icon
  end

  def icon_class
    "fa fa-#{icon_name} w-8"
  end
end

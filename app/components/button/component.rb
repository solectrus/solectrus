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
      dark:text-gray-300
      bg-indigo-600
      dark:bg-indigo-800
      hover:bg-indigo-700
      shadow-sm
      px-3
      hover:scale-105
      focus:outline-hidden
      focus:ring-2
      focus:ring-offset-2
      focus:ring-indigo-500
      dark:focus:ring-offset-slate-800
      click-animation
    ]
  end

  def btn_secondary_class
    if icon
      %w[
        hover:scale-125
        focus:outline-hidden
        focus:ring-2
        focus:ring-offset-2
        focus:ring-indigo-500
        dark:focus:ring-offset-slate-800
        click-animation
      ]
    else
      %w[underline underline-offset-4]
    end
  end

  def btn_tertiary_class
    []
  end

  def icon_name
    icon.is_a?(Hash) ? icon.fetch(:name) : icon
  end

  def icon_class
    ['fa', "fa-#{icon_name}", ('w-8' unless title)]
  end
end

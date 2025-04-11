class OuterLink::Component < ViewComponent::Base
  def initialize(url:, **options)
    super
    @url = url
    @options = options
  end

  def call
    tag.div(**options) { content }
  end

  private

  def options
    @options.merge(class: merged_class, data: merged_data)
  end

  def merged_data
    data = @options[:data]&.dup || {}

    data[:controller] = token_list(data[:controller], 'outer-link--component')

    data[:outer_link__component_url_value] = @url
    data[:outer_link__component_frame_value] = data.delete(:turbo_frame)
    data[:outer_link__component_action_value] = data.delete(:turbo_action)

    data
  end

  def merged_class
    token_list(@options[:class], 'cursor-pointer')
  end
end

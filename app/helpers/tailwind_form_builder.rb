class TailwindFormBuilder < ActionView::Helpers::FormBuilder
  attr_reader :template, :options, :object_name

  def group(title: nil, &)
    tag.div(class: 'text-gray-500 text-sm md:text-base') { title } +
      tag.div(class: 'mb-10 pt-4 grid grid-cols-1 gap-4', &)
  end

  def actions(&)
    tag.div(class: 'mt-10 flex justify-between', &)
  end

  def submit(title)
    render Button::Component.new(type: :submit, title:)
  end

  def text_field(method, options = {}) # rubocop:disable Style/OptionHash
    default_options = { class: input_html_classes(method) }
    default_options[:class] << (options[:maxlength] ? 'w-20' : 'w-full')
    merged_options = default_options.merge(options)

    tag.div class: 'form-control' do
      label(method, class: 'label') do
        tag.span(label_text(method, merged_options), class: 'label-text')
      end + super(method, merged_options) + errors(method)
    end
  end

  def number_field(method, options = {}) # rubocop:disable Style/OptionHash
    default_options = { class: input_html_classes(method) }
    default_options[:class] << (options[:maxlength] ? 'w-20' : 'w-full')
    merged_options = default_options.merge(options)

    tag.div class: 'form-control' do
      label(method, class: 'label') do
        tag.span(label_text(method, merged_options), class: 'label-text')
      end + super(method, merged_options) + errors(method)
    end
  end

  def password_field(method, options = {}) # rubocop:disable Style/OptionHash
    default_options = { class: input_html_classes(method) }
    default_options[:class] << (options[:maxlength] ? 'w-20' : 'w-full')
    merged_options = default_options.merge(options)

    tag.div class: 'form-control' do
      label(method, class: 'label') do
        tag.span(label_text(method, merged_options), class: 'label-text')
      end + super(method, merged_options) +
        tag.span(merged_options[:hint], class: 'mt-3 label-hint') +
        errors(method)
    end
  end

  def date_field(method, options = {}) # rubocop:disable Style/OptionHash
    default_options = { class: input_html_classes(method) }
    default_options[:class] << 'w-full'
    merged_options = default_options.merge(options)

    tag.div class: 'form-control' do
      label(method, class: 'label') do
        tag.span(label_text(method, merged_options), class: 'label-text')
      end + super(method, merged_options) + errors(method)
    end
  end

  def check_box(method, options = {}) # rubocop:disable Style/OptionHash
    default_options = { class: 'form-checkbox mt-1' }
    merged_options = default_options.merge(options)

    tag.div class: 'form-control flex-row items-start gap-3' do
      super(method, merged_options) +
        label(method, class: 'label flex flex-col py-0') do
          tag.span(label_text(method, merged_options), class: 'label-text') +
            tag.span(merged_options[:hint], class: 'label-hint')
        end + errors(method)
    end
  end

  private

  delegate :tag, :link_to, :safe_join, :render, to: :template

  def input_html_classes(method)
    ['form-input', ('input-error' if error?(method))]
  end

  def label_text(method, options)
    options.fetch(:label) { object.class.human_attribute_name(method) }
  end

  def errors(method)
    return unless error?(method)

    tag.ul class: 'mt-2 text-sm text-red-500' do
      safe_join(object.errors[method].map { |error| tag.li(error) })
    end
  end

  def error?(method)
    object && object.errors[method].present?
  end
end

# The Rails default is wrapping the error field into <div class="fields_with_error">...</div>
# This makes styling complicated, so just render the plain html tag.
# Error handling is done by `input_html_classes`.
ActionView::Base.field_error_proc = proc { |html_tag, _instance| html_tag }

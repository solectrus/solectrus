class TailwindFormBuilder < ActionView::Helpers::FormBuilder
  attr_reader :template, :options, :object_name

  def group(title: nil, &)
    safe_join(
      [
        (tag.div(title, class: 'text-gray-500 text-sm md:text-base') if title),
        tag.div(class: 'mb-10 pt-4 grid grid-cols-1 gap-4', &),
      ].compact,
    )
  end

  def actions(&)
    tag.div(class: 'mt-10 flex justify-between', &)
  end

  def submit(title)
    render Button::Component.new(type: :submit, title:)
  end

  def text_field(method, **, &)
    input_field(:text_field, method, **, &)
  end

  def number_field(method, **, &)
    input_field(:number_field, method, **, &)
  end

  def password_field(method, **options)
    hint = options.delete(:hint)
    input_field(:password_field, method, hint: hint, **options) do
      tag.span(hint, class: 'mt-3 label-hint') if hint
    end
  end

  def date_field(method, **, &)
    input_field(:date_field, method, **, &)
  end

  def check_box(method, **options)
    hint = options.delete(:hint)
    options[:class] = tag.classes(
      [options[:class], 'form-checkbox', ('mt-0.5' if hint)],
    )

    tag.div class: [
              'form-control mt-1 flex-row gap-3',
              hint ? 'items-start' : 'items-center',
            ] do
      super(method, options) +
        label(method, class: 'label flex flex-col py-0') do
          safe_join(
            [
              tag.span(label_text(method, options), class: 'label-text'),
              (tag.span(hint, class: 'label-hint') if hint),
            ].compact,
          )
        end + errors(method)
    end
  end

  private

  delegate :tag, :link_to, :safe_join, :render, to: :template

  def input_field(field_type, method, **options)
    options[:class] = tag.classes(
      [
        options[:class],
        'form-input',
        ('input-error' if error?(method)),
        (options[:maxlength] ? 'w-20' : 'w-full'),
      ],
    )

    tag.div class: 'form-control' do
      label(method, class: 'label') do
        tag.span(label_text(method, options), class: 'label-text')
      end +
        safe_join(
          [
            @template.public_send(
              field_type,
              @object_name,
              method,
              objectify_options(options),
            ),
            (yield if block_given?),
            errors(method),
          ].compact,
        )
    end
  end

  def label_text(method, options)
    options.fetch(:label) { object.class.human_attribute_name(method) }
  end

  def errors_for(method)
    object&.errors&.[](method)
  end

  def error?(method)
    errors_for(method).present?
  end

  def errors(method)
    return unless errors_for(method)

    tag.ul class: 'mt-2 text-sm text-red-500' do
      safe_join(errors_for(method).map { |error| tag.li(error) })
    end
  end
end

# The Rails default is wrapping the error field into <div class="fields_with_error">...</div>
# This makes styling complicated, so just render the plain html tag.
# Error handling is done by `input_field`.
ActionView::Base.field_error_proc = ->(html_tag, _instance) { html_tag }

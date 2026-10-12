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

  def text_area(method, **, &)
    input_field(:text_area, method, **, &)
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

  %i[date_field datetime_local_field].each do |field_type|
    define_method(field_type) { |method, **options, &block| input_field(field_type, method, **options, &block) }
  end

  def select(method, choices = nil, options = {}, html_options = {}, &)
    hint = options.delete(:hint)
    label = label_text(method, options)
    options.delete(:label)
    html_options[:class] = [
      html_options[:class],
      'form-select w-full',
      ('input-error' if error?(method)),
    ].compact.join(' ')

    tag.div class: 'form-control' do
      label(method, class: 'label') do
        tag.span(label, class: 'label-text')
      end +
        safe_join(
          [
            super,
            (hint_tag(hint) if hint),
            errors(method),
          ].compact,
        )
    end
  end

  def check_box(method, **options)
    hint = options.delete(:hint)
    # Pull the label out before calling super, so it never leaks onto the input
    # as an HTML attribute. May be an html_safe string (e.g. label text plus an
    # info tooltip).
    label_content = label_text(method, options)
    options.delete(:label)
    options[:class] = [
      options[:class],
      'form-checkbox',
      ('mt-0.5' if hint),
    ].compact.join(' ')

    tag.div class: [
              'form-control mt-1 flex-row gap-3',
              hint ? 'items-start' : 'items-center',
            ] do
      super(method, options) +
        label(method, class: 'label flex flex-col py-0') do
          safe_join(
            [
              tag.span(label_content, class: 'label-text'),
              (tag.span(hint, class: 'label-hint') if hint),
            ].compact,
          )
        end + errors(method)
    end
  end

  private

  delegate :tag, :link_to, :safe_join, :render, to: :template

  def input_field(field_type, method, **options)
    hint = options.delete(:hint)
    suffix = options.delete(:suffix)
    show_label = options[:label] != false
    options.delete(:label) unless show_label
    options[:class] = input_classes(options, method, suffix)

    input =
      @template.public_send(
        field_type,
        @object_name,
        method,
        objectify_options(options),
      )
    input = with_suffix(input, suffix) if suffix

    tag.div class: 'form-control' do
      safe_join(
        [
          (input_label(method, options) if show_label),
          input,
          (yield if block_given?),
          (hint_tag(hint) if hint && !block_given?),
          errors(method),
        ].compact,
      )
    end
  end

  def input_classes(options, method, suffix)
    [
      options[:class],
      'form-input',
      ('input-error' if error?(method)),
      # Keep the text clear of the suffix pinned to the right edge
      ('pr-12' if suffix),
      (options[:maxlength] ? 'w-20' : 'w-full'),
    ].compact.join(' ')
  end

  def input_label(method, options)
    label(method, class: 'label') do
      tag.span(label_text(method, options), class: 'label-text')
    end
  end

  # Pin a unit (e.g. "km") to the right edge of the input
  def with_suffix(input, suffix)
    tag.div(class: 'relative') do
      input +
        tag.span(
          suffix,
          class:
            'absolute inset-y-0 right-3 flex items-center text-gray-500 pointer-events-none',
        )
    end
  end

  # Render a hint below an input, honoring embedded newlines as line breaks
  def hint_tag(hint)
    tag.span(safe_join(hint.split("\n"), tag.br), class: 'mt-3 label-hint')
  end

  def label_text(method, options)
    options.fetch(:label) { object.class.human_attribute_name(method) }
  end

  def errors_for(method) = object&.errors&.[](method)

  def error?(method) = errors_for(method).present?

  def errors(method)
    return unless errors_for(method)

    tag.ul class: 'mt-2 text-sm text-signal-negative' do
      safe_join(errors_for(method).map { |error| tag.li(error) })
    end
  end
end

# The Rails default is wrapping the error field into <div class="fields_with_error">...</div>
# This makes styling complicated, so just render the plain html tag.
# Error handling is done by `input_field`.
ActionView::Base.field_error_proc = ->(html_tag, _instance) { html_tag }

# @label Message
class MessageComponentPreview < ViewComponent::Preview
  def generic
    render Message::Component.new do |component|
      component.with_header { 'Header' }

      component.with_title { 'This is the title' }

      component.with_body do
        'Consequat in anim labore cupidatat fugiat ea sunt excepteur ea et amet. Ea aliquip pariatur voluptate commodo dolor occaecat sunt. Occaecat pariatur laborum deserunt aliquip commodo dolor ipsum irure est. Eiusmod elit quis cillum do officia. Cillum Lorem incididunt amet cupidatat consequat commodo occaecat amet deserunt ad in.'
      end

      component.with_footer { 'This is the footer' }
    end
  end

  # The symbol above the title keeps its own size, unlike the watermark, which
  # sits behind the text.
  def with_icon
    render Message::Component.new do |component|
      component.with_icon { tag.i(class: 'fa fa-message text-6xl text-indigo-600') }

      component.with_title { 'This is the title' }

      component.with_body { 'A short explanation below the title.' }
    end
  end

  def with_watermark
    render Message::Component.new do |component|
      component.with_watermark { tag.i(class: 'fa fa-sack-dollar') }

      component.with_title { 'This is the title' }

      component.with_body { 'A short explanation below the title.' }
    end
  end
end

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
end

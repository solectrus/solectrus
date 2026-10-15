describe Ui::ConfirmDialog::Component, type: :component do
  before { render_inline(described_class.new) }

  it 'renders a dialog that stays across visits' do
    dialog = page.find("dialog##{described_class::ID}", visible: :all)
    aggregate_failures do
      expect(dialog['role']).to eq('alertdialog')
      expect(dialog['data-controller']).to eq('ui--confirm-dialog--component')
      expect(dialog['data-turbo-permanent']).not_to be_nil
    end
  end

  it 'answers with the value of its buttons, and the cancel button takes the focus' do
    aggregate_failures do
      expect(page.find_button('Cancel', visible: :all)['value']).to eq('cancel')
      expect(page.find_button('Cancel', visible: :all)['autofocus']).not_to be_nil
      expect(page.find_button('Yes', visible: :all)['value']).to eq('confirm')
    end
  end
end

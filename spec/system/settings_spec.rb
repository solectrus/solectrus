describe 'Settings', js: true do
  let!(:price1) do
    Price.electricity.create! starts_at: Date.new(2020, 10, 1),
                              value: 0.2545,
                              note: 'First price'
  end

  let!(:price2) do
    Price.feed_in.create! starts_at: Date.new(2020, 10, 1),
                          value: 0.0812,
                          note: 'Second price'
  end

  it 'can render prices list' do
    visit prices_path

    expect(page).to have_text(Price.human_enum_name(:name, :electricity).upcase)

    expect(page).to have_text(price1.note)
    expect(page).not_to have_text(price2.note)
  end

  context 'when not admin' do
    it 'cannot see buttons for add/edit/delete' do
      visit prices_path

      expect(page).not_to have_button(I18n.t('crud.new'))
      expect(page).not_to have_button(I18n.t('crud.edit'))
      expect(page).not_to have_button(I18n.t('crud.delete'))
    end

    it 'cannot add price' do
      visit new_price_path

      expect(page).to have_current_path(new_session_path)
    end
  end

  context 'when admin', js: true do
    before { login_as_admin }

    it 'can edit price' do
      visit prices_path
      expect(page).not_to have_text('Testing note')

      click_on I18n.t('crud.edit')
      within css_id(price1, :form) do
        fill_in Price.human_attribute_name(:note), with: 'Testing note'
        fill_in Price.human_attribute_name(:value), with: ''

        click_on I18n.t('crud.save')

        expect(page).to have_text(I18n.t('errors.messages.not_a_number'))
        fill_in Price.human_attribute_name(:value), with: '0.25'
        click_on I18n.t('crud.save')
      end
      expect(page).to have_text('Testing note')
    end

    it 'can delete price' do
      # Create other price to make sure we can delete this one
      Price.electricity.create! starts_at: Date.new(2019, 1, 1), value: 0.21

      visit prices_path
      expect(page).to have_css('.table-row-group .table-row', count: 2)

      expect(page).to have_button(I18n.t('crud.delete'))
      accept_confirm { click_on I18n.t('crud.delete'), match: :first }
      expect(page).to have_css('.table-row-group .table-row', count: 1)
    end

    it 'can add price' do
      visit prices_path

      expect(page).to have_button(I18n.t('crud.new'))
      click_on I18n.t('crud.new')
      within css_id(Price.new, :form) do
        fill_in Price.human_attribute_name(:value), with: 0.25
        fill_in Price.human_attribute_name(:note), with: 'This is the new price'

        click_on I18n.t('crud.save')
        expect(page).to have_text(I18n.t('errors.messages.blank'))

        fill_in Price.human_attribute_name(:starts_at), with: Date.current
        click_on I18n.t('crud.save')
      end

      expect(page).to have_css('.table', text: 'This is the new price')
      expect(page).to have_css('.table', text: '0,2500 €')
    end
  end
end

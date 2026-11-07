describe 'Settings heat pump' do
  before { allow(Heatpump::Comparison).to receive(:available?).and_return(true) }

  context 'when logged in as admin' do
    before { login_as_admin }

    describe 'GET /settings/heatpump' do
      it 'shows the form of the heating' do
        get edit_settings_heatpump_path

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.at_css('select#heatpump_heating_fuel_type')).to be_present
      end

      it 'proposes a gas heating before the admin saves one' do
        get edit_settings_heatpump_path

        expect(response.parsed_body.at_css('select#heatpump_heating_fuel_type option[selected]')['value']).to eq('gas')
        expect(response.parsed_body.at_css('input#heatpump_heating_efficiency')['value']).to eq('85')
      end

      it 'shows no efficiency without a fuel' do
        Setting.heatpump_heating_fuel_type = ''

        get edit_settings_heatpump_path

        expect(response.parsed_body.at_css('select#heatpump_heating_fuel_type option[selected]')).to be_nil
        expect(response.parsed_body.at_css('input#heatpump_heating_efficiency')['value']).to be_nil
      end

      it 'is a tab of the settings' do
        get settings_path

        expect(response.parsed_body.css("a[href='#{edit_settings_heatpump_path}']")).to be_present
      end

      context 'without the comparison' do
        before { allow(Heatpump::Comparison).to receive(:available?).and_return(false) }

        it 'leads to the settings' do
          get edit_settings_heatpump_path

          expect(response).to redirect_to(settings_path)
        end
      end

      context 'without the heat pump page' do
        before { allow(Setting).to receive(:enable_heatpump).and_return(false) }

        it 'leads to the settings' do
          get edit_settings_heatpump_path

          expect(response).to redirect_to(settings_path)
        end
      end
    end

    describe 'PATCH /settings/heatpump' do
      it 'saves the heating' do
        patch settings_heatpump_path, params: { heatpump_heating: { fuel_type: 'gas', efficiency: '85', fixed_costs: '120.50' } }

        expect(response).to redirect_to(edit_settings_heatpump_path)
        expect(Setting.heatpump_heating_fuel_type).to eq('gas')
        expect(Setting.heatpump_heating_efficiency).to eq(85)
        expect(Setting.heatpump_heating_fixed_costs).to eq(120.5)
      end

      # The empty fuel stays, so the default does not come back
      it 'saves no comparison and clears the efficiency and the fixed costs' do
        Setting.heatpump_heating_efficiency = 85
        Setting.heatpump_heating_fixed_costs = 100

        patch settings_heatpump_path, params: { heatpump_heating: { fuel_type: '', efficiency: '85', fixed_costs: '100' } }

        expect(response).to redirect_to(edit_settings_heatpump_path)
        expect(Heatpump::Heating.current).to have_attributes(fuel_type: nil, efficiency: nil, fixed_costs: nil)
        expect(Setting.heatpump_heating_fixed_costs).to be_nil
      end

      it 'keeps an efficiency out of range' do
        patch settings_heatpump_path, params: { heatpump_heating: { fuel_type: 'heating_oil', efficiency: '120' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(Setting.heatpump_heating_fuel_type).to eq('gas')
      end

      it 'shows one error for a blank efficiency' do
        patch settings_heatpump_path, params: { heatpump_heating: { fuel_type: 'gas', efficiency: '' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.text).to include("can't be blank")
        expect(response.parsed_body.text).not_to include('is not a number')
      end
    end
  end

  context 'when not logged in' do
    it 'asks for the login' do
      get edit_settings_heatpump_path

      expect(response).to have_http_status(:forbidden)
    end
  end
end

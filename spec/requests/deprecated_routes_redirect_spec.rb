describe DeprecatedRoutesRedirect do
  context 'when /bat_power' do
    subject { get '/bat_power' }

    it { is_expected.to redirect_to('/battery_power') }
  end

  context 'when /bat_power/:timeframe' do
    subject { get '/bat_power/day' }

    it { is_expected.to redirect_to('/battery_power/day') }
  end

  context 'when /wallbox_charge_power' do
    subject { get '/wallbox_charge_power' }

    it { is_expected.to redirect_to('/wallbox_power') }
  end

  context 'when /wallbox_charge_power/:timeframe' do
    subject { get '/wallbox_charge_power/day' }

    it { is_expected.to redirect_to('/wallbox_power/day') }
  end

  context 'when /bat_fuel_charge' do
    subject { get '/bat_fuel_charge' }

    it { is_expected.to redirect_to('/battery_soc') }
  end

  context 'when /bat_fuel_charge/:timeframe' do
    subject { get '/bat_fuel_charge/week' }

    it { is_expected.to redirect_to('/battery_soc/week') }
  end

  context 'when /top10/day/wallbox_charge_power/sum/desc' do
    subject { get '/top10/day/wallbox_charge_power/sum/desc' }

    it { is_expected.to redirect_to('/top10/day/wallbox_power/sum/desc') }
  end

  context 'when /top10/day/bat_power_minus/sum/desc' do
    subject { get '/top10/day/bat_power_minus/sum/desc' }

    it do
      is_expected.to redirect_to('/top10/day/battery_charging_power/sum/desc')
    end
  end

  context 'when /top10/day/bat_power_plus/sum/desc' do
    subject { get '/top10/day/bat_power_plus/sum/desc' }

    it do
      is_expected.to redirect_to(
        '/top10/day/battery_discharging_power/sum/desc',
      )
    end
  end
end

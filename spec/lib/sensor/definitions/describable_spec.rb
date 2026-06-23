describe Sensor::Definitions::Describable do
  def sensor(name)
    Sensor::Registry.find(name)
  end

  describe '#description' do
    it 'returns the translated description of a root sensor' do
      I18n.with_locale(:en) do
        expect(sensor(:house_power).description).to eq(
          'Total household electricity consumption.',
        )
      end

      I18n.with_locale(:de) do
        expect(sensor(:house_power).description).to eq(
          'Gesamter Hausverbrauch (Strom).',
        )
      end
    end

    it 'derives split sensor descriptions from the base label, bilingually' do
      I18n.with_locale(:en) do
        expect(sensor(:house_costs_grid).description).to eq(
          'Portion of "House costs" supplied from grid-imported electricity ' \
            '(as opposed to own PV).',
        )
      end

      I18n.with_locale(:de) do
        expect(sensor(:house_costs_grid).description).to eq(
          'Anteil von "Hauskosten", der aus dem Netz gedeckt wird ' \
            '(statt aus eigener PV).',
        )
      end
    end

    it 'derives descriptions for templated sensors' do
      I18n.with_locale(:en) do
        expect(sensor(:inverter_power_1).description).to eq(
          'PV generation of inverter/string 1.',
        )
        expect(sensor(:custom_power_01).description).to eq(
          'Power draw of user-defined custom consumer 1.',
        )
      end
    end

    it 'covers every configured sensor in both locales' do
      %i[en de].each do |locale|
        I18n.with_locale(locale) do
          missing = Sensor::Registry.all.select { |s| s.description.blank? }
          expect(missing).to be_empty
        end
      end
    end
  end

  describe '#display_name' do
    it 'derives a label for split sensors instead of the raw machine name' do
      I18n.with_locale(:en) do
        expect(sensor(:house_costs_grid).display_name).to eq('House costs (Grid)')
      end

      I18n.with_locale(:de) do
        expect(sensor(:house_costs_grid).display_name).to eq('Hauskosten (Netz)')
      end
    end

    it 'never leaks a raw machine name in either locale' do
      %i[en de].each do |locale|
        I18n.with_locale(locale) do
          leaks =
            Sensor::Registry.all.select { |s| s.display_name.to_s == s.name.to_s }
          expect(leaks).to be_empty
        end
      end
    end
  end
end

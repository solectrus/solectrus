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

  # Separates the labels an operator chose from the ones the app derived, so a
  # caller can publish the former without carrying the latter twice.
  describe '#user_defined_name?' do
    before do
      allow(Setting).to receive(:sensor_names).and_return(
        { custom_power_01: 'Waschmaschine' },
      )
    end

    it 'is true for a sensor the operator named' do
      expect(sensor(:custom_power_01)).to be_user_defined_name
    end

    it 'is false for a sensor left at its translated label' do
      expect(sensor(:house_power)).not_to be_user_defined_name
    end

    # A custom cost sensor has no name of its own - it borrows the consumer's.
    # So it inherits whether that name was chosen by the operator, otherwise
    # "Waschmaschine (Costs)" would be just as undiscoverable as the consumer.
    it 'is true for the cost sensor borrowing that name' do
      expect(sensor(:custom_01_costs)).to be_user_defined_name
      expect(sensor(:custom_01_costs).display_name).to eq('Waschmaschine (Costs)')
    end

    it 'is false for the cost sensor of an unnamed consumer' do
      expect(sensor(:custom_02_costs)).not_to be_user_defined_name
    end
  end
end

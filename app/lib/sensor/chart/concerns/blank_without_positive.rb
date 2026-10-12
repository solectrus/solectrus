module Sensor
  module Chart
    module Concerns
      # A chart whose 0 means that nothing happened, like a car that did not
      # drive or charge, is empty without a positive value
      module BlankWithoutPositive
        def blank?
          super || data[:datasets].none? { |dataset| dataset[:data].any? { it&.positive? } }
        end
      end
    end
  end
end

module McpServer
  module Tools
    # What the tools that write share. A client reads the same document more
    # than once, so an entry is found again before one is added. The rules of
    # an entry stay in its model: a tool only reports what the model rejects.
    module Recording
      # The `reference` input-schema property of a payment
      REFERENCE_PROPERTY = {
        type: 'string',
        minLength: 1,
        description:
          'The number of the document, like the number of a bill. Give it ' \
          'whenever the document has one.',
      }.freeze
      public_constant :REFERENCE_PROPERTY

      # The `note` input-schema property of an optional note
      NOTE_PROPERTY = {
        type: %w[string null],
        description: 'A short note, e.g. what was paid. null removes it.',
      }.freeze
      public_constant :NOTE_PROPERTY

      # The `id` input-schema property: the entry of an earlier answer, which
      # the call changes (see #own_entry). A call with it changes only the
      # arguments that it gives. `needed` are the arguments that a call
      # without it needs, because they find or add the entry (see
      # #require_without_id). The schema cannot require them only without
      # `id`, so the description names them.
      def self.id_property(*needed)
        {
          type: 'integer',
          minimum: 1,
          description:
            'The id of an entry with origin mcp, from an answer or a list: the call ' \
            'changes only the arguments that it gives, the others keep their ' \
            "value. Without id, give #{needed.to_sentence(locale: :en)}.",
        }
      end

      protected

      # The arguments that a call without `id` needs, because they find or add
      # the entry. With `id`, each argument is optional.
      def require_without_id(id, args, needed)
        missing = needed.select { args[it].blank? }
        return if id || missing.empty?

        raise ArgumentError, "Missing #{missing.join(', ')}: #{missing.one? ? 'it is' : 'they are'} needed without `id`."
      end

      # The car that the call gives, nil without one. An unknown number names
      # the cars of the instance, so the client can pick the right one.
      def car_of(args)
        return unless args.key?(:car)

        Car.configured.find { it.id == args[:car].to_i } ||
          raise(ArgumentError, "Unknown car #{args[:car]}. This instance has: #{Car.configured.map { "#{it.id} (#{it.display_name})" }.join(', ')}.")
      end

      # The arguments with the date of `key` read as ISO 8601, where the call
      # gives it
      def with_date(args, key)
        args.key?(key) ? args.merge(key => iso_date(args[key], key.to_s)) : args
      end

      # The entry of `id` in `scope`, which an AI agent wrote and the admin did
      # not save since. A save is the check of the admin, so an agent can
      # correct its own entry but never one that the admin checked or wrote.
      def own_entry(scope, id)
        scope.find_by(id:, origin: :mcp) or
          raise ArgumentError,
                "No entry #{id} to change by id: an id finds only an entry with origin mcp, " \
                'which an AI agent recorded and the admin has not saved since.'
      end

      # Adds or changes a payment of `scope`. The `id` of an earlier answer, or
      # else the number of its document, finds it. Without them, an entry with
      # the same values of `match` is the same payment, unless it has a number
      # of another document: then the tool adds nothing and names the entry.
      # The block serializes an entry.
      def record_payment(scope, reference:, attributes:, match:, arguments:, id: nil, &)
        entry, twin = payment_of(scope, id:, reference:, match:)
        return { result: 'exists', entry: yield(twin), hint: EXISTS_HINT } if twin

        previous = yield(entry) if entry.persisted?
        entry.assign_attributes(attributes)
        entry.reference = reference if reference
        result = save_entry(entry, arguments)

        { result:, entry: yield(entry), previous: (previous if result == 'updated') }.compact
      end

      # [the entry to save, an equal payment that is the one of the document]
      def payment_of(scope, id:, reference:, match:)
        return [own_entry(scope, id), nil] if id

        existing = scope.find_by(reference:) if reference
        return [existing, nil] if existing

        # One without a number, or any for a call without a number
        twin = (reference ? scope.where(reference: nil) : scope).find_by(match)
        [scope.new(reference:), twin]
      end

      EXISTS_HINT =
        'An entry with the same date, category and amount exists, so nothing ' \
        'was added. If this is another payment, call again with the number ' \
        'of its document as `reference`.'.freeze
      private_constant :EXISTS_HINT

      # Saves an entry as written by an AI client, and returns what happened
      # to it. An entry without a change stays as it is, also its origin.
      # `arguments` names the argument of each attribute for an error. A
      # block saves the entry in place of `save`.
      def save_entry(entry, arguments)
        return 'unchanged' if entry.persisted? && !entry.changed?

        result = entry.new_record? ? 'created' : 'updated'
        entry.origin = :mcp
        # `save`, not `save!`: the errors of the model become the answer
        (block_given? ? yield : entry.save) or raise ArgumentError, rejection(entry, arguments) # rubocop:disable Rails/SaveBang
        result
      end

      # The attributes that the given arguments set, by the map of argument to
      # attribute. An argument that is left out sets nothing.
      def attributes_from(args, arguments)
        arguments.filter_map { |argument, attribute| [attribute, args[argument]] if args.key?(argument) }.to_h
      end

      # Only ISO 8601, unlike the dates that a reading tool takes: a write
      # must not guess the date from a word like "Monday"
      def iso_date(value, label)
        Date.iso8601(value.to_s)
      rescue Date::Error
        raise ArgumentError, "Invalid #{label}: #{value.inspect} is not an ISO 8601 date (e.g. \"2026-01-01\")."
      end

      # A time in ISO 8601 with its offset. Without the offset, the time of a
      # receipt can be the local time of another zone, so the tool does not
      # guess it.
      ISO_TIME = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})\z/
      private_constant :ISO_TIME

      # DateTime, because Time.iso8601 needs the seconds and turns an
      # impossible date like February 30 into March 2
      def iso_time(value, label)
        raise Date::Error unless value.to_s.match?(ISO_TIME)

        DateTime.iso8601(value).to_time.in_time_zone # rubocop:disable Style/DateTime
      rescue Date::Error
        raise ArgumentError, "Invalid #{label}: #{value.inspect} is not an ISO 8601 time with its offset (e.g. \"2026-03-15T14:05:00+01:00\")."
      end

      private

      # The errors of the model, named by the arguments of the tool
      def rejection(entry, arguments)
        names = arguments.invert
        messages = I18n.with_locale(:en) { entry.errors.map { "#{names.fetch(it.attribute, it.attribute)} #{it.message}" } }

        "Nothing was saved: #{messages.to_sentence.delete_suffix('.')}."
      end
    end
  end
end

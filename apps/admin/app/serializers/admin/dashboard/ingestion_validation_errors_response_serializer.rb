module Admin
  module Dashboard
    class IngestionValidationErrorsResponseSerializer
      def serialize(errors:)
        {
          "contractVersion" => "v1",
          "errors" => Array(errors).map { |error| serialize_entry(error) }
        }
      end

      private

      def serialize_entry(error)
        {
          "source" => error[:source],
          "field" => error[:field],
          "message" => error[:message],
          "occurredAt" => error[:occurredAt],
          "correlationId" => error[:correlationId]
        }
      end
    end
  end
end

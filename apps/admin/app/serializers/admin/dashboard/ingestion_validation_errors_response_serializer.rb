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
          "occurred_at" => error[:occurred_at],
          "correlation_id" => error[:correlation_id]
        }
      end
    end
  end
end

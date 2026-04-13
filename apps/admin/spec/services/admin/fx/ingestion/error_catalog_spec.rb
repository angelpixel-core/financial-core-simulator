require "rails_helper"

RSpec.describe Admin::Fx::Ingestion::ErrorCatalog do
  describe ".details_for" do
    it "returns catalog details for known codes" do
      details = described_class.details_for("mapping_failed")

      expect(details[:error_code]).to eq("mapping_failed")
      expect(details[:severity]).to eq("warning")
      expect(details[:user_message_key]).to eq("admin.fx.ingestion_errors.mapping_failed.message")
      expect(details[:action_hint_key]).to eq("admin.fx.ingestion_errors.mapping_failed.action_hint")
    end

    it "returns a fallback entry for unknown codes" do
      details = described_class.details_for("unknown_code")

      expect(details[:error_code]).to eq("unknown_code")
      expect(details[:severity]).to eq("error")
      expect(details[:user_message_key]).to eq("admin.fx.ingestion_errors.unknown.message")
      expect(details[:action_hint_key]).to eq("admin.fx.ingestion_errors.unknown.action_hint")
    end
  end
end

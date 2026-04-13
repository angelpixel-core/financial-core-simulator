# frozen_string_literal: true

require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "Admin FX API",
        version: "v1"
      },
      components: {
        securitySchemes: {
          AdminUser: {
            type: :apiKey,
            name: "X-Admin-User",
            in: :header
          },
          AdminRole: {
            type: :apiKey,
            name: "X-Admin-Role",
            in: :header
          }
        },
        schemas: {
          FxIngestion: {
            type: :object,
            properties: {
              ingestion_id: {type: :integer},
              source_id: {type: :integer},
              status: {type: :string}
            },
            required: %i[ingestion_id source_id status]
          },
          FxIngestionSource: {
            type: :object,
            properties: {
              source_id: {type: :integer},
              source_name: {type: :string},
              ingestion_id: {type: :integer, nullable: true},
              status: {type: :string, nullable: true},
              error_code: {type: :string, nullable: true},
              created_at: {type: :string, format: :date_time, nullable: true},
              updated_at: {type: :string, format: :date_time, nullable: true}
            },
            required: %i[source_id source_name]
          },
          FxIngestionList: {
            type: :object,
            properties: {
              sources: {
                type: :array,
                items: {"$ref" => "#/components/schemas/FxIngestionSource"}
              }
            },
            required: %i[sources]
          },
          FxHistoryRate: {
            type: :object,
            properties: {
              id: {type: :integer},
              operational_date: {type: :string, format: :date},
              base_currency: {type: :string},
              quote_currency: {type: :string},
              rate: {type: :string, nullable: true},
              source: {type: :string},
              source_id: {type: :integer, nullable: true}
            }
          },
          FxHistoryEvent: {
            type: :object,
            properties: {
              event_type: {type: :string},
              created_at: {type: :string, format: :date_time},
              error_code: {type: :string, nullable: true},
              severity: {type: :string, nullable: true}
            }
          },
          FxHistoryLineage: {
            type: :object,
            properties: {
              source: {type: :string, nullable: true},
              source_id: {type: :integer, nullable: true},
              source_label: {type: :string, nullable: true},
              ingestion_id: {type: :integer, nullable: true},
              ingestion_status: {type: :string, nullable: true},
              upload_id: {type: :integer, nullable: true},
              upload_status: {type: :string, nullable: true},
              created_by_id: {type: :string, nullable: true},
              created_by_role: {type: :string, nullable: true},
              created_at: {type: :string, format: :date_time, nullable: true},
              updated_at: {type: :string, format: :date_time, nullable: true},
              placeholder_gap_id: {type: :integer, nullable: true},
              placeholder_gap_status: {type: :string, nullable: true},
              events: {
                type: :array,
                items: {"$ref" => "#/components/schemas/FxHistoryEvent"}
              }
            }
          },
          FxHistoryResponse: {
            type: :object,
            properties: {
              source_id: {type: :integer, nullable: true},
              source_name: {type: :string, nullable: true},
              sort_order: {type: :string},
              dates: {type: :array, items: {type: :string, format: :date}},
              pairs: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    base_currency: {type: :string},
                    quote_currency: {type: :string}
                  },
                  required: %i[base_currency quote_currency]
                }
              },
              rates_by_pair: {
                type: :object,
                additionalProperties: {
                  type: :object,
                  additionalProperties: {"$ref" => "#/components/schemas/FxHistoryRate"}
                }
              },
              lineage: {
                type: :object,
                additionalProperties: {"$ref" => "#/components/schemas/FxHistoryLineage"}
              }
            },
            required: %i[dates pairs rates_by_pair lineage]
          }
        }
      },
      security: [
        {AdminUser: [], AdminRole: []}
      ],
      paths: {}
    }
  }

  config.openapi_format = :yaml
end

require "json"
require "fileutils"

def write_artifacts(run:, global:, accounts:)
  base_dir = Rails.root.join("storage", "runs", "dashboard_seed", "run_#{run.id}")
  FileUtils.mkdir_p(base_dir)

  result_path = base_dir.join("result.json")
  positions_path = base_dir.join("positions.csv")
  pnl_path = base_dir.join("pnl.csv")

  payload = {
    "schemaVersion" => "1.0",
    "runId" => run.id,
    "global" => global,
    "accounts" => accounts
  }

  File.write(result_path, JSON.pretty_generate(payload))
  File.write(positions_path, "account_id,market_id,quantity_base,mark_price_quote\nacc-1,BTC-USD,0.5,61000\n")
  File.write(pnl_path, "account_id,total_pnl_quote,realized_net_pnl_quote,unrealized_pnl_quote\nacc-1,125.50,100.00,25.50\n")

  run.update!(
    artifacts: {
      "result_json_path" => result_path.to_s,
      "positions_csv_path" => positions_path.to_s,
      "pnl_csv_path" => pnl_path.to_s
    }
  )
end

def create_succeeded_run(index:, seconds_ago:)
  run = Run.create!(
    status: :succeeded,
    created_at: seconds_ago.seconds.ago,
    updated_at: seconds_ago.seconds.ago,
    duration_ms: 850 + (index * 210),
    input_hash: "seed-dashboard-#{SecureRandom.hex(6)}",
    schema_version: "1.0",
    engine_version: "1.0",
    input_json: {
      "schemaVersion" => "1.0",
      "accounts" => [
        { "accountId" => "acc-1" },
        { "accountId" => "acc-2" },
        { "accountId" => "acc-3" }
      ]
    }
  )

  write_artifacts(
    run: run,
    global: {
      "totalPnLQuote" => format("%.2f", 180.0 - (index * 22.0)),
      "realizedNetPnLQuote" => format("%.2f", 140.0 - (index * 18.0)),
      "unrealizedPnLQuote" => format("%.2f", 40.0 - (index * 4.0)),
      "totalPnLUsd" => format("%.2f", 180.0 - (index * 22.0))
    },
    accounts: [
      {
        "accountId" => "acc-1",
        "totals" => {
          "totalPnLQuote" => format("%.2f", 125.5 - (index * 10.0)),
          "realizedNetPnLQuote" => format("%.2f", 100.0 - (index * 8.0)),
          "unrealizedPnLQuote" => format("%.2f", 25.5 - (index * 2.0))
        }
      },
      {
        "accountId" => "acc-2",
        "totals" => {
          "totalPnLQuote" => format("%.2f", 42.0 - (index * 5.0)),
          "realizedNetPnLQuote" => format("%.2f", 30.0 - (index * 4.0)),
          "unrealizedPnLQuote" => format("%.2f", 12.0 - (index * 1.0))
        }
      },
      {
        "accountId" => "acc-3",
        "totals" => {
          "totalPnLQuote" => format("%.2f", -12.0 + (index * 1.5)),
          "realizedNetPnLQuote" => format("%.2f", -9.0 + (index * 1.2)),
          "unrealizedPnLQuote" => format("%.2f", -3.0 + (index * 0.3))
        }
      }
    ]
  )

  run
end

def create_validation_failure(source:, error_code:, message:, correlation_id:)
  Run.create!(
    status: :failed,
    error_code: error_code,
    error_message: message,
    input_json: {
      "correlationId" => correlation_id,
      "timeline" => {
        "events" => [
          { "source" => source }
        ]
      }
    }
  )
end

puts "Seeding dashboard demo data..."

create_succeeded_run(index: 0, seconds_ago: 120)
create_succeeded_run(index: 1, seconds_ago: 2400)
create_succeeded_run(index: 2, seconds_ago: 86000)

Run.create!(status: :queued, input_json: { "schemaVersion" => "1.0" })
Run.create!(status: :running, input_json: { "schemaVersion" => "1.0" })

create_validation_failure(
  source: "source.agent.internal",
  error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
  message: "risk invalid",
  correlation_id: "seed-corr-a"
)
create_validation_failure(
  source: "source.venue.external",
  error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
  message: "accounting invalid",
  correlation_id: "seed-corr-b"
)
create_validation_failure(
  source: "agente.hft.alpha",
  error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
  message: "risk invalid",
  correlation_id: "seed-corr-c"
)

puts "Done."
puts "Runs total: #{Run.count}"
puts "Succeeded: #{Run.succeeded.count} | Failed: #{Run.failed.count} | Running: #{Run.running.count} | Queued: #{Run.queued.count}"
puts "Open overview: /admin/overview"

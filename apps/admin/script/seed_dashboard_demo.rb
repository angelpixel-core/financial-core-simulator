require "json"
require "fileutils"

SEED_NAMESPACE = "seed-dashboard" unless defined?(SEED_NAMESPACE)
TOP_ACCOUNT_IDS = %w[acc-1 acc-2 acc-3 acc-4 acc-5 acc-6].freeze unless defined?(TOP_ACCOUNT_IDS)

def decimal_str(value)
  format("%.2f", value)
end

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

  positions_rows = [ "account_id,market_id,quantity_base,mark_price_quote" ]
  pnl_rows = [ "account_id,total_pnl_quote,realized_net_pnl_quote,unrealized_pnl_quote" ]
  accounts.each_with_index do |account, index|
    account_id = account.fetch("accountId")
    totals = account.fetch("totals", {})
    quantity = decimal_str(0.25 + (index * 0.11))
    mark_price = decimal_str(58_500 + (index * 950))

    positions_rows << "#{account_id},BTC-USD,#{quantity},#{mark_price}"
    pnl_rows << [
      account_id,
      totals.fetch("totalPnLQuote", "0.00"),
      totals.fetch("realizedNetPnLQuote", "0.00"),
      totals.fetch("unrealizedPnLQuote", "0.00")
    ].join(",")
  end

  File.write(result_path, JSON.pretty_generate(payload))
  File.write(positions_path, positions_rows.join("\n") + "\n")
  File.write(pnl_path, pnl_rows.join("\n") + "\n")

  run.update!(
    artifacts: {
      "result_json_path" => result_path.to_s,
      "positions_csv_path" => positions_path.to_s,
      "pnl_csv_path" => pnl_path.to_s
    }
  )
end

def build_accounts(day_offset:)
  TOP_ACCOUNT_IDS.each_with_index.map do |account_id, index|
    direction = index.even? ? 1 : -1
    base = 180 - (day_offset * 5) - (index * 17)
    total = direction * base
    realized = total * 0.7
    unrealized = total * 0.3

    {
      "accountId" => account_id,
      "totals" => {
        "totalPnLQuote" => decimal_str(total),
        "realizedNetPnLQuote" => decimal_str(realized),
        "unrealizedPnLQuote" => decimal_str(unrealized)
      }
    }
  end
end

def build_global(accounts)
  totals = accounts.map { |account| account.fetch("totals") }

  total_pnl_quote = totals.sum { |entry| entry.fetch("totalPnLQuote").to_f }
  realized_net = totals.sum { |entry| entry.fetch("realizedNetPnLQuote").to_f }
  unrealized = totals.sum { |entry| entry.fetch("unrealizedPnLQuote").to_f }

  {
    "totalPnLQuote" => decimal_str(total_pnl_quote),
    "realizedNetPnLQuote" => decimal_str(realized_net),
    "unrealizedPnLQuote" => decimal_str(unrealized),
    "totalPnLUsd" => decimal_str(total_pnl_quote * 1.03)
  }
end

def upsert_succeeded_run(day_offset:)
  created_at = Time.current.beginning_of_day - day_offset.days + 12.hours
  run_uuid = "#{SEED_NAMESPACE}-succeeded-#{day_offset}"
  input_hash = "#{SEED_NAMESPACE}-hash-#{day_offset}"

  run = Run.find_or_initialize_by(run_uuid: run_uuid)
  run.assign_attributes(
    status: :succeeded,
    created_at: created_at,
    updated_at: created_at,
    duration_ms: 420 + ((13 - day_offset) * 33),
    input_hash: input_hash,
    schema_version: "1.0",
    engine_version: "1.1",
    input_json: {
      "schemaVersion" => "1.0",
      "seededFrom" => created_at.utc.iso8601,
      "accounts" => TOP_ACCOUNT_IDS.map { |account_id| { "accountId" => account_id } }
    }
  )
  run.save!

  accounts = build_accounts(day_offset: day_offset)

  write_artifacts(
    run: run,
    global: build_global(accounts),
    accounts: accounts
  )

  run
end

def upsert_validation_failure(source:, error_code:, message:, correlation_id:, day_offset:)
  created_at = Time.current.beginning_of_day - day_offset.days + 4.hours + (day_offset % 4).hours
  run_uuid = "#{SEED_NAMESPACE}-validation-#{correlation_id}"

  run = Run.find_or_initialize_by(run_uuid: run_uuid)
  run.assign_attributes(
    status: :failed,
    created_at: created_at,
    updated_at: created_at,
    input_hash: "#{SEED_NAMESPACE}-failed-#{correlation_id}",
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
  run.save!
end

def upsert_transient_run(status:, suffix:, day_offset: 0, hour_offset: 0)
  created_at = Time.current.beginning_of_day - day_offset.days + 8.hours + hour_offset.hours
  run_uuid = "#{SEED_NAMESPACE}-#{status}-#{suffix}"

  run = Run.find_or_initialize_by(run_uuid: run_uuid)
  run.assign_attributes(
    status: status,
    created_at: created_at,
    updated_at: created_at,
    input_hash: "#{SEED_NAMESPACE}-#{status}-hash-#{suffix}",
    input_json: {
      "schemaVersion" => "1.0",
      "seeded" => true,
      "state" => status.to_s
    }
  )
  run.save!
end

puts "Seeding dashboard demo data..."

(0..29).to_a.reverse_each do |day_offset|
  upsert_succeeded_run(day_offset: day_offset)
end

upsert_transient_run(status: :queued, suffix: "main", day_offset: 0, hour_offset: 1)
upsert_transient_run(status: :running, suffix: "main", day_offset: 0, hour_offset: 2)
upsert_transient_run(status: :queued, suffix: "backup", day_offset: 1, hour_offset: 3)
upsert_transient_run(status: :running, suffix: "backup", day_offset: 2, hour_offset: 2)

upsert_validation_failure(
  source: "source.agent.internal",
  error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
  message: "risk invalid",
  correlation_id: "seed-corr-a",
  day_offset: 0
)
upsert_validation_failure(
  source: "source.venue.external",
  error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
  message: "accounting invalid",
  correlation_id: "seed-corr-b",
  day_offset: 2
)
upsert_validation_failure(
  source: "agente.hft.alpha",
  error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
  message: "risk invalid",
  correlation_id: "seed-corr-c",
  day_offset: 4
)
upsert_validation_failure(
  source: "faucet.erc20.ang",
  error_code: Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
  message: "accounts collateral mismatch",
  correlation_id: "seed-corr-d",
  day_offset: 7
)
upsert_validation_failure(
  source: "source.market.snapshots",
  error_code: Runs::ErrorCodeMapper::VALIDATION_RISK,
  message: "riskModel stale window",
  correlation_id: "seed-corr-e",
  day_offset: 10
)

puts "Done."
puts "Runs total: #{Run.count}"
puts [
  "Succeeded: #{Run.succeeded.count}",
  "Failed: #{Run.failed.count}",
  "Running: #{Run.running.count}",
  "Queued: #{Run.queued.count}"
].join(" | ")
puts "Open overview: /admin/overview"

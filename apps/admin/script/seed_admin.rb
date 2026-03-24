# frozen_string_literal: true

require "json"
require "optparse"
require "fileutils"
require "bcrypt"

module SeedAdminEvidence
  def self.reset!
    @artifacts = []
    @details = {}
  end

  def self.add_artifact(path)
    return if path.nil?

    artifacts << path.to_s
  end

  def self.add_artifacts(paths)
    Array(paths).each { |path| add_artifact(path) }
  end

  def self.add_detail(key, value)
    details[key.to_s] = value
  end

  def self.artifacts
    @artifacts ||= []
  end

  def self.details
    @details ||= {}
  end
end

module SeedAdminFlows
  module_function

  def upsert_account(email:, password:, status: :verified)
    account = Account.find_or_initialize_by(email: email)
    account.password_hash = BCrypt::Password.create(password)
    account.status = status
    account.save!
    account
  end

  def seed_verified_runs
    puts "Seeding verified runs..."

    run_count = 30
    seed_namespace = "verified-seed"
    account_emails = {
      "ops@example.com" => "operator",
      "admin@example.com" => "admin"
    }
    password = "secret-pass"
    account_ids = %w[acc-1 acc-2 acc-3]
    market_ids = %w[ETH-USD BTC-USD]

    build_input = lambda do |day_offset|
      timestamp = (Time.now.utc - day_offset.days).strftime("%Y-%m-%dT%H:%M:%SZ")
      price_shift = (day_offset % 7) * 50

      {
        "schemaVersion" => "1.0",
        "accounts" => account_ids.map { |account_id| {"accountId" => account_id} },
        "markets" => market_ids.map { |market_id| {"marketId" => market_id} },
        "feeModel" => {"enabled" => true},
        "trades" => [
          {
            "tradeId" => "#{seed_namespace}-trade-#{day_offset}",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "timestamp" => day_offset + 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "0.5",
            "priceQuotePerBase" => (2200 + price_shift).to_s,
            "fee" => {"amountQuote" => "3"}
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => timestamp,
          "prices" => [
            {"marketId" => "ETH-USD", "priceQuotePerBase" => (2300 + price_shift).to_s},
            {"marketId" => "BTC-USD", "priceQuotePerBase" => (52_000 + price_shift * 10).to_s}
          ],
          "fx" => {"quoteUsd" => "1"}
        }
      }
    end

    account_emails.each_key do |email|
      upsert_account(email: email, password: password)
    end

    runs = []

    run_count.times do |index|
      day_offset = run_count - 1 - index
      input = build_input.call(day_offset)

      run = Run.create!(
        input_json: input,
        created_at: Time.current.beginning_of_day - day_offset.days + 9.hours,
        updated_at: Time.current.beginning_of_day - day_offset.days + 9.hours
      )

      Runs::Execute.new.call(run)
      Runs::VerifyInputHash.new.call(run)

      runs << run
    end

    puts "Verified runs created: #{runs.length}"
    puts "Latest run id: #{runs.last&.id}"
    puts "Login credentials: ops@example.com / #{password}\nadmin@example.com / #{password}"

    SeedAdminEvidence.add_detail("verified_run_count", runs.length)
    SeedAdminEvidence.add_detail("latest_run_id", runs.last&.id)
    SeedAdminEvidence.add_detail("seeded_accounts", account_emails.keys)
  end

  def seed_local_demo
    puts "Seeding local demo data..."

    password = "secret-pass"
    upsert_account(email: "ops@example.com", password: password)
    upsert_account(email: "admin@example.com", password: password)

    seed_verified_runs

    puts "Done."

    SeedAdminEvidence.add_detail("local_demo", true)
    SeedAdminEvidence.add_detail("seeded_accounts", ["ops@example.com", "admin@example.com"])
  end

  def seed_interactive_runs
    puts "Seeding interactive runs (execute/verify)..."

    seed_namespace = "interactive-seed"
    execute_count = 5
    verify_count = 5

    account_ids = %w[acc-1 acc-2]
    market_ids = %w[ETH-USD BTC-USD]

    build_input = lambda do |seed, offset|
      timestamp = (Time.now.utc - offset.days).strftime("%Y-%m-%dT%H:%M:%SZ")
      price_shift = seed * 25

      {
        "schemaVersion" => "1.0",
        "accounts" => account_ids.map { |account_id| {"accountId" => account_id} },
        "markets" => market_ids.map { |market_id| {"marketId" => market_id} },
        "feeModel" => {"enabled" => true},
        "trades" => [
          {
            "tradeId" => "#{seed_namespace}-trade-#{seed}",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "timestamp" => seed + 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "0.4",
            "priceQuotePerBase" => (2200 + price_shift).to_s,
            "fee" => {"amountQuote" => "2"}
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => timestamp,
          "prices" => [
            {"marketId" => "ETH-USD", "priceQuotePerBase" => (2300 + price_shift).to_s},
            {"marketId" => "BTC-USD", "priceQuotePerBase" => (52_000 + price_shift * 8).to_s}
          ],
          "fx" => {"quoteUsd" => "1"}
        }
      }
    end

    execute_runs = []
    execute_count.times do |index|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-execute-#{index}",
        input_json: build_input.call(index, index),
        status: :queued,
        created_at: Time.current - (index + 1).hours,
        updated_at: Time.current - (index + 1).hours
      )
      execute_runs << run
    end

    verify_runs = []
    verify_count.times do |index|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-verify-#{index}",
        input_json: build_input.call(index + 100, index),
        created_at: Time.current - (index + 1).days,
        updated_at: Time.current - (index + 1).days
      )

      Runs::Execute.new.call(run)
      run.update!(verification_status: "unverified", verified_at: nil, verification_input_hash: nil)
      verify_runs << run
    end

    puts "Interactive execute runs: #{execute_runs.map(&:id).join(", ")}\nInteractive verify runs: #{verify_runs.map(&:id).join(", ")}"

    SeedAdminEvidence.add_detail("execute_run_ids", execute_runs.map(&:id))
    SeedAdminEvidence.add_detail("verify_run_ids", verify_runs.map(&:id))
    SeedAdminEvidence.add_detail("execute_run_count", execute_runs.length)
    SeedAdminEvidence.add_detail("verify_run_count", verify_runs.length)
  end

  def seed_ops_daily
    puts "Seeding daily ops scenarios..."

    seed_namespace = "ops-daily"
    today = Time.now.utc

    account_emails = {
      "ops@example.com" => "operator",
      "admin@example.com" => "admin"
    }
    password = "secret-pass"
    account_ids = %w[acc-1 acc-2 acc-3]
    market_ids = %w[ETH-USD BTC-USD]

    build_input = lambda do |seed, offset_days|
      timestamp = (today - offset_days.days).strftime("%Y-%m-%dT%H:%M:%SZ")
      price_shift = seed * 25

      {
        "schemaVersion" => "1.0",
        "accounts" => account_ids.map { |account_id| {"accountId" => account_id} },
        "markets" => market_ids.map { |market_id| {"marketId" => market_id} },
        "feeModel" => {"enabled" => true},
        "trades" => [
          {
            "tradeId" => "#{seed_namespace}-trade-#{seed}",
            "accountId" => "acc-1",
            "marketId" => "ETH-USD",
            "timestamp" => seed + 1,
            "seq" => 1,
            "side" => "BUY",
            "quantityBase" => "0.4",
            "priceQuotePerBase" => (2200 + price_shift).to_s,
            "fee" => {"amountQuote" => "2"}
          }
        ],
        "priceSnapshot" => {
          "valuationTimestamp" => timestamp,
          "prices" => [
            {"marketId" => "ETH-USD", "priceQuotePerBase" => (2300 + price_shift).to_s},
            {"marketId" => "BTC-USD", "priceQuotePerBase" => (52_000 + price_shift * 8).to_s}
          ],
          "fx" => {"quoteUsd" => "1"}
        }
      }
    end

    account_emails.each_key do |email|
      upsert_account(email: email, password: password)
    end

    verified_ids = []
    verify_ids = []
    execute_ids = []
    running_ids = []
    failed_ids = []
    mismatch_ids = []
    verification_error_ids = []

    10.times do |i|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-verified-#{i}",
        input_json: build_input.call(i, i),
        created_at: today - i.days + 9.hours,
        updated_at: today - i.days + 9.hours
      )
      Runs::Execute.new.call(run)
      Runs::VerifyInputHash.new.call(run)
      verified_ids << run.id
    end

    5.times do |i|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-verify-#{i}",
        input_json: build_input.call(i + 100, i + 1),
        created_at: today - (i + 1).days + 11.hours,
        updated_at: today - (i + 1).days + 11.hours
      )
      Runs::Execute.new.call(run)
      run.update!(verification_status: "unverified", verified_at: nil, verification_input_hash: nil)
      verify_ids << run.id
    end

    5.times do |i|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-execute-#{i}",
        input_json: build_input.call(i + 200, 0),
        status: :queued,
        created_at: today - i.hours,
        updated_at: today - i.hours
      )
      execute_ids << run.id
    end

    2.times do |i|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-running-#{i}",
        input_json: build_input.call(i + 300, 0),
        status: :running,
        created_at: today - (i + 1).hours,
        updated_at: today - (i + 1).hours
      )
      running_ids << run.id
    end

    3.times do |i|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-failed-#{i}",
        input_json: {"schemaVersion" => "1.0"},
        status: :failed,
        error_code: "ERR_VALIDATION_GENERAL",
        error_message: "Missing required field",
        created_at: today - (i + 2).days + 2.hours,
        updated_at: today - (i + 2).days + 2.hours
      )
      failed_ids << run.id
    end

    2.times do |i|
      run = Run.create!(
        run_uuid: "#{seed_namespace}-mismatch-#{i}",
        input_json: build_input.call(i + 400, i + 3),
        created_at: today - (i + 3).days + 5.hours,
        updated_at: today - (i + 3).days + 5.hours
      )
      Runs::Execute.new.call(run)
      Runs::VerifyInputHash.new.call(run)
      run.update!(input_hash: "mismatch-#{run.input_hash}")
      mismatch_ids << run.id
    end

    run = Run.create!(
      run_uuid: "#{seed_namespace}-verification-error",
      input_json: {},
      status: :succeeded,
      created_at: today - 1.day + 6.hours,
      updated_at: today - 1.day + 6.hours,
      input_hash: nil
    )
    Runs::VerifyInputHash.new.call(run)
    verification_error_ids << run.id

    puts "Done."
    puts "Verified runs (no action needed): #{verified_ids.join(", ")}" unless verified_ids.empty?
    puts "Runs to verify (click Verify now): #{verify_ids.join(", ")}" unless verify_ids.empty?
    puts "Runs to execute (click Execute now): #{execute_ids.join(", ")}" unless execute_ids.empty?
    puts "Running runs (in-progress): #{running_ids.join(", ")}" unless running_ids.empty?
    puts "Failed validation runs: #{failed_ids.join(", ")}" unless failed_ids.empty?
    puts "Mismatch runs: #{mismatch_ids.join(", ")}" unless mismatch_ids.empty?
    puts "Verification error runs: #{verification_error_ids.join(", ")}" unless verification_error_ids.empty?
    puts "Login credentials: ops@example.com / #{password}\nadmin@example.com / #{password}"

    SeedAdminEvidence.add_detail("verified_run_ids", verified_ids)
    SeedAdminEvidence.add_detail("verify_run_ids", verify_ids)
    SeedAdminEvidence.add_detail("execute_run_ids", execute_ids)
    SeedAdminEvidence.add_detail("running_run_ids", running_ids)
    SeedAdminEvidence.add_detail("failed_run_ids", failed_ids)
    SeedAdminEvidence.add_detail("mismatch_run_ids", mismatch_ids)
    SeedAdminEvidence.add_detail("verification_error_run_ids", verification_error_ids)
    SeedAdminEvidence.add_detail("verified_run_count", verified_ids.length)
    SeedAdminEvidence.add_detail("verify_run_count", verify_ids.length)
    SeedAdminEvidence.add_detail("execute_run_count", execute_ids.length)
    SeedAdminEvidence.add_detail("running_run_count", running_ids.length)
    SeedAdminEvidence.add_detail("failed_run_count", failed_ids.length)
    SeedAdminEvidence.add_detail("mismatch_run_count", mismatch_ids.length)
    SeedAdminEvidence.add_detail("verification_error_run_count", verification_error_ids.length)
    SeedAdminEvidence.add_detail("seeded_accounts", account_emails.keys)
  end

  def seed_dashboard_demo
    Admin::Seeds::DashboardDemoSeed.new(
      evidence: SeedAdminEvidence,
      logger: seed_admin_logger
    ).call
  end

  def seed_admin_logger
    return nil unless ENV["SEED_ADMIN_VERBOSE"] == "1"

    $stdout
  end
end

SUPPORTED_TYPES = {
  "verified" => :seed_verified_runs,
  "interactive" => :seed_interactive_runs,
  "dashboard" => :seed_dashboard_demo,
  "ops" => :seed_ops_daily,
  "local-demo" => :seed_local_demo
}.freeze

options = {
  type: nil,
  dry_run: false,
  verbose: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: rails runner apps/admin/script/seed_admin.rb --type TYPE [--dry-run] [--verbose]"
  opts.on("--type=TYPE", String, "Seed type (#{SUPPORTED_TYPES.keys.join(", ")})") do |value|
    options[:type] = value
  end
  opts.on("--dry-run", "Show what would run without executing") do
    options[:dry_run] = true
  end
  opts.on("--verbose", "Verbose output") do
    options[:verbose] = true
  end
end

parser.parse!

type = options[:type]

unless SUPPORTED_TYPES.key?(type)
  supported = SUPPORTED_TYPES.keys.join(", ")
  puts "Unsupported seed type: #{type || "(none)"}"
  puts "Supported types: #{supported}"
  puts parser.banner
  puts "status: failure"
  puts "type: #{type || "unknown"}"
  puts "artifacts: []"
  puts "report_path: none"
  exit 1
end

report_dir = Rails.root.join("storage", "runs", "seed_reports")
FileUtils.mkdir_p(report_dir)
report_path = report_dir.join("seed_#{Time.now.utc.strftime("%Y%m%dT%H%M%SZ")}.json")

status = "success"
failure = nil
SeedAdminEvidence.reset!

if options[:dry_run]
  status = "dry_run"
else
  begin
    ENV["SEED_ADMIN_ENTRY"] = "1"
    ENV["SEED_ADMIN_TYPE"] = type
    ENV["SEED_ADMIN_VERBOSE"] = options[:verbose] ? "1" : "0"
    puts "Running seed type: #{type}" if options[:verbose]
    method_name = SUPPORTED_TYPES.fetch(type)
    SeedAdminFlows.public_send(method_name)
  rescue => e
    status = "failure"
    failure = {
      "errorClass" => e.class.name,
      "message" => e.message,
      "backtrace" => e.backtrace&.first(10)
    }
  end
end

evidence_artifacts = SeedAdminEvidence.artifacts
artifacts = if evidence_artifacts.any?
  evidence_artifacts.uniq
else
  case type
  when "dashboard"
    base = Rails.root.join("storage", "runs", "dashboard_seed")
    Dir.exist?(base) ? [base.to_s] : []
  else
    []
  end
end

report = {
  "status" => status,
  "type" => type,
  "artifacts" => artifacts,
  "evidence" => SeedAdminEvidence.details,
  "failure" => failure,
  "created_at" => Time.now.utc.iso8601
}

File.write(report_path, JSON.pretty_generate(report))

puts "status: #{status}"
puts "type: #{type}"
puts "artifacts: #{artifacts}"
puts "evidence: #{SeedAdminEvidence.details}"
puts "report_path: #{report_path}"
puts "failure: #{failure}" if failure

# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'time'

module Admin
  module Seeds
    class DashboardDemoSeed
      def initialize(evidence: nil, logger: nil)
        @evidence = evidence
        @logger = logger
      end

      def call
        log 'Seeding dashboard demo data...'

        seed_namespace = 'seed-dashboard'
        top_account_ids = %w[acc-1 acc-2 acc-3 acc-4 acc-5 acc-6]

        (0..29).to_a.reverse_each do |day_offset|
          dashboard_upsert_succeeded_run(
            seed_namespace: seed_namespace,
            top_account_ids: top_account_ids,
            day_offset: day_offset
          )
        end

        dashboard_upsert_transient_run(seed_namespace: seed_namespace, status: :queued, suffix: 'main', day_offset: 0,
                                       hour_offset: 1)
        dashboard_upsert_transient_run(seed_namespace: seed_namespace, status: :running, suffix: 'main', day_offset: 0,
                                       hour_offset: 2)
        dashboard_upsert_transient_run(seed_namespace: seed_namespace, status: :queued, suffix: 'backup',
                                       day_offset: 1, hour_offset: 3)
        dashboard_upsert_transient_run(seed_namespace: seed_namespace, status: :running, suffix: 'backup',
                                       day_offset: 2, hour_offset: 2)

        dashboard_upsert_validation_failure(
          seed_namespace: seed_namespace,
          source: 'source.agent.internal',
          error_code: ::Runs::ErrorCodeMapper::VALIDATION_RISK,
          message: 'risk invalid',
          correlation_id: 'seed-corr-a',
          day_offset: 0
        )
        dashboard_upsert_validation_failure(
          seed_namespace: seed_namespace,
          source: 'source.venue.external',
          error_code: ::Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
          message: 'accounting invalid',
          correlation_id: 'seed-corr-b',
          day_offset: 2
        )
        dashboard_upsert_validation_failure(
          seed_namespace: seed_namespace,
          source: 'agente.hft.alpha',
          error_code: ::Runs::ErrorCodeMapper::VALIDATION_RISK,
          message: 'risk invalid',
          correlation_id: 'seed-corr-c',
          day_offset: 4
        )
        dashboard_upsert_validation_failure(
          seed_namespace: seed_namespace,
          source: 'faucet.erc20.ang',
          error_code: ::Runs::ErrorCodeMapper::VALIDATION_ACCOUNTING,
          message: 'accounts collateral mismatch',
          correlation_id: 'seed-corr-d',
          day_offset: 7
        )
        dashboard_upsert_validation_failure(
          seed_namespace: seed_namespace,
          source: 'source.market.snapshots',
          error_code: ::Runs::ErrorCodeMapper::VALIDATION_RISK,
          message: 'riskModel stale window',
          correlation_id: 'seed-corr-e',
          day_offset: 10
        )

        summary = summary_counts
        log 'Done.'
        log "Runs total: #{summary.fetch(:runs_total)}"
        log [
          "Succeeded: #{summary.fetch(:runs_succeeded)}",
          "Failed: #{summary.fetch(:runs_failed)}",
          "Running: #{summary.fetch(:runs_running)}",
          "Queued: #{summary.fetch(:runs_queued)}"
        ].join(' | ')
        log 'Open overview: /admin/overview'

        evidence&.add_detail('runs_total', summary.fetch(:runs_total))
        evidence&.add_detail('runs_succeeded', summary.fetch(:runs_succeeded))
        evidence&.add_detail('runs_failed', summary.fetch(:runs_failed))
        evidence&.add_detail('runs_running', summary.fetch(:runs_running))
        evidence&.add_detail('runs_queued', summary.fetch(:runs_queued))
        evidence&.add_artifact(dashboard_seed_dir)

        summary
      end

      private

      attr_reader :evidence, :logger

      def log(message)
        logger&.puts(message)
      end

      def summary_counts
        {
          runs_total: Run.count,
          runs_succeeded: Run.succeeded.count,
          runs_failed: Run.failed.count,
          runs_running: Run.running.count,
          runs_queued: Run.queued.count
        }
      end

      def dashboard_seed_dir
        Rails.root.join('storage', 'runs', 'dashboard_seed')
      end

      def dashboard_decimal_str(value)
        format('%.2f', value)
      end

      def dashboard_computed_input_hash(input_json)
        normalized = JSON.parse(JSON.generate(input_json))
        fee_enabled = normalized.dig('feeModel', 'enabled')
        fee_enabled = true if fee_enabled.nil?
        normalized['feeModel'] ||= {}
        normalized['feeModel']['enabled'] = !!fee_enabled
        normalized['trades'] = FCS::Engine::TradeSorter.new.sort(normalized.fetch('trades', []))

        canonical = FCS::Hashing::CanonicalJSON.dump(normalized)
        FCS::Hashing::SHA256.hex(canonical)
      end

      def dashboard_write_artifacts(run:, global:, accounts:)
        base_dir = dashboard_seed_dir.join("run_#{run.id}")
        FileUtils.mkdir_p(base_dir)

        result_path = base_dir.join('result.json')
        positions_path = base_dir.join('positions.csv')
        pnl_path = base_dir.join('pnl.csv')

        payload = {
          'schemaVersion' => '1.0',
          'runId' => run.id,
          'global' => global,
          'accounts' => accounts
        }

        positions_rows = ['account_id,market_id,quantity_base,mark_price_quote']
        pnl_rows = ['account_id,total_pnl_quote,realized_net_pnl_quote,unrealized_pnl_quote']
        accounts.each_with_index do |account, index|
          account_id = account.fetch('accountId')
          totals = account.fetch('totals', {})
          quantity = dashboard_decimal_str(0.25 + (index * 0.11))
          mark_price = dashboard_decimal_str(58_500 + (index * 950))

          positions_rows << "#{account_id},BTC-USD,#{quantity},#{mark_price}"
          pnl_rows << [
            account_id,
            totals.fetch('totalPnLQuote', '0.00'),
            totals.fetch('realizedNetPnLQuote', '0.00'),
            totals.fetch('unrealizedPnLQuote', '0.00')
          ].join(',')
        end

        File.write(result_path, JSON.pretty_generate(payload))
        File.write(positions_path, positions_rows.join("\n") + "\n")
        File.write(pnl_path, pnl_rows.join("\n") + "\n")

        run.update!(
          artifacts: {
            'result_json_path' => result_path.to_s,
            'positions_csv_path' => positions_path.to_s,
            'pnl_csv_path' => pnl_path.to_s
          }
        )
      end

      def dashboard_build_accounts(top_account_ids:, day_offset:)
        top_account_ids.each_with_index.map do |account_id, index|
          direction = index.even? ? 1 : -1
          base = 180 - (day_offset * 5) - (index * 17)
          total = direction * base
          realized = total * 0.7
          unrealized = total * 0.3

          {
            'accountId' => account_id,
            'totals' => {
              'totalPnLQuote' => dashboard_decimal_str(total),
              'realizedNetPnLQuote' => dashboard_decimal_str(realized),
              'unrealizedPnLQuote' => dashboard_decimal_str(unrealized)
            }
          }
        end
      end

      def dashboard_build_global(accounts)
        totals = accounts.map { |account| account.fetch('totals') }

        total_pnl_quote = totals.sum { |entry| entry.fetch('totalPnLQuote').to_f }
        realized_net = totals.sum { |entry| entry.fetch('realizedNetPnLQuote').to_f }
        unrealized = totals.sum { |entry| entry.fetch('unrealizedPnLQuote').to_f }

        {
          'totalPnLQuote' => dashboard_decimal_str(total_pnl_quote),
          'realizedNetPnLQuote' => dashboard_decimal_str(realized_net),
          'unrealizedPnLQuote' => dashboard_decimal_str(unrealized),
          'totalPnLUsd' => dashboard_decimal_str(total_pnl_quote * 1.03)
        }
      end

      def dashboard_upsert_succeeded_run(seed_namespace:, top_account_ids:, day_offset:)
        created_at = Time.current.beginning_of_day - day_offset.days + 12.hours
        run_uuid = "#{seed_namespace}-succeeded-#{day_offset}"

        run = Run.find_or_initialize_by(run_uuid: run_uuid)
        input_json = {
          'schemaVersion' => '1.0',
          'seededFrom' => created_at.utc.iso8601,
          'accounts' => top_account_ids.map { |account_id| { 'accountId' => account_id } }
        }
        input_hash = dashboard_computed_input_hash(input_json)

        run.assign_attributes(
          status: :succeeded,
          created_at: created_at,
          updated_at: created_at,
          duration_ms: 420 + ((13 - day_offset) * 33),
          input_hash: input_hash,
          schema_version: '1.0',
          engine_version: '1.1',
          input_json: input_json,
          verification_status: 'verified',
          verified_at: created_at,
          verification_input_hash: input_hash,
          verification_error: nil
        )
        run.save!

        accounts = dashboard_build_accounts(top_account_ids: top_account_ids, day_offset: day_offset)

        dashboard_write_artifacts(
          run: run,
          global: dashboard_build_global(accounts),
          accounts: accounts
        )

        run
      end

      def dashboard_upsert_validation_failure(seed_namespace:, source:, error_code:, message:, correlation_id:,
                                              day_offset:)
        created_at = Time.current.beginning_of_day - day_offset.days + 4.hours + (day_offset % 4).hours
        run_uuid = "#{seed_namespace}-validation-#{correlation_id}"

        run = Run.find_or_initialize_by(run_uuid: run_uuid)
        run.assign_attributes(
          status: :failed,
          created_at: created_at,
          updated_at: created_at,
          input_hash: "#{seed_namespace}-failed-#{correlation_id}",
          error_code: error_code,
          error_message: message,
          input_json: {
            'correlationId' => correlation_id,
            'timeline' => {
              'events' => [
                { 'source' => source }
              ]
            }
          }
        )
        run.save!
      end

      def dashboard_upsert_transient_run(seed_namespace:, status:, suffix:, day_offset:, hour_offset:)
        created_at = Time.current.beginning_of_day - day_offset.days + 8.hours + hour_offset.hours
        run_uuid = "#{seed_namespace}-#{status}-#{suffix}"

        run = Run.find_or_initialize_by(run_uuid: run_uuid)
        run.assign_attributes(
          status: status,
          created_at: created_at,
          updated_at: created_at,
          input_hash: "#{seed_namespace}-#{status}-hash-#{suffix}",
          input_json: {
            'schemaVersion' => '1.0',
            'seeded' => true,
            'state' => status.to_s
          }
        )
        run.save!
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Fx
    class UpdateDailyRate
      def initialize(repository: Admin::Fx::Rates::Repository.new)
        @repository = repository
      end

      def call(rate_id:, rate:, created_by_id:, created_by_role:, created_context:)
        daily_rate = @repository.find(rate_id)

        unless daily_rate.manual? || daily_rate.placeholder?
          daily_rate.errors.add(:base, I18n.t('admin.fx.flash.rate_edit_blocked'))
          raise ActiveRecord::RecordInvalid, daily_rate
        end

        context = daily_rate.created_context || {}
        daily_rate.assign_attributes(
          rate: rate,
          source: 'manual',
          source_rate_id: nil,
          source_run_id: nil,
          source_upload_id: nil,
          created_by_id: created_by_id,
          created_by_role: created_by_role,
          created_context: context.merge(created_context)
        )

        @repository.save!(daily_rate)
        Admin::Fx::GapResolver.call(rate: daily_rate)
        daily_rate
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Fx
    class DeleteDailyRate
      def initialize(repository: Admin::Fx::Repositories::ActiveRecord::DailyRateRepository.new)
        @repository = repository
      end

      def call(rate_id:)
        daily_rate = @repository.find(rate_id)

        if !daily_rate.manual? || daily_rate.linked_to_system?
          daily_rate.errors.add(:base, I18n.t('admin.fx.flash.rate_delete_blocked'))
          raise ActiveRecord::RecordInvalid, daily_rate
        end

        @repository.destroy!(daily_rate)
      end
    end
  end
end

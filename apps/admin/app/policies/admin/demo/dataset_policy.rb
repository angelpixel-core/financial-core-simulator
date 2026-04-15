module Admin
  module Demo
    class DatasetPolicy < ApplicationPolicy
      def create?
        operator?
      end

      def preview?
        operator?
      end

      def reset?
        operator?
      end
    end
  end
end

# frozen_string_literal: true

module FCS
  module Engine
    class TradeSorter
      def sort(trades)
        trades.sort_by do |t|
          ts = t.fetch("timestamp")
          seq = t.fetch("seq")
          [ts, seq]
        end
      end
    end
  end
end

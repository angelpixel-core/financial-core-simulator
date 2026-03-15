# frozen_string_literal: true

require "bigdecimal"

module FCS
  module Types
    # Fixed-point decimal with scale 1e18.
    # Internal representation: integer "atoms" (scaled by 1e18).
    class Decimal18
      SCALE = 10**18

      attr_reader :atoms

      def initialize(atoms)
        raise ArgumentError, "atoms must be Integer" unless atoms.is_a?(Integer)

        @atoms = atoms
      end

      def self.from_rational(num, den = 1)
        raise ArgumentError, "den must be > 0" unless den.is_a?(Integer) && den > 0
        raise ArgumentError, "num must be Integer" unless num.is_a?(Integer)

        # floor(num/den * 1e18) determinista
        new((num * SCALE) / den)
      end

      def self.from_string(str)
        bd = BigDecimal(str)
        # floor(bd * 1e18)
        atoms = (bd * SCALE).floor
        new(atoms.to_i)
      end

      def +(other) = self.class.new(@atoms + other.atoms)
      def -(other) = self.class.new(@atoms - other.atoms)

      def *(other)
        # floor((a*b)/SCALE)
        self.class.new((@atoms * other.atoms) / SCALE)
      end

      def /(other)
        raise ZeroDivisionError if other.atoms == 0

        # floor((a*SCALE)/b)
        self.class.new((@atoms * SCALE) / other.atoms)
      end

      def zero? = @atoms == 0

      def abs = self.class.new(@atoms.abs)

      def to_bigdecimal
        BigDecimal(@atoms) / SCALE
      end

      def to_s
        to_bigdecimal.to_s("F")
      end
    end
  end
end

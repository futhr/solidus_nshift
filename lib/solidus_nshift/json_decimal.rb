# frozen_string_literal: true

require "bigdecimal"

module SolidusNshift
  class JsonDecimal
    attr_reader :value

    def initialize(value)
      @value = BigDecimal(value.to_s)
      raise ValidationError, "decimal value must be finite" unless @value.finite?

      freeze
    rescue ArgumentError, TypeError
      raise ValidationError, "value is not a decimal"
    end

    def to_json(*)
      value.to_s("F")
    end

    def as_json(*)
      self
    end

    def ==(other)
      value == (other.respond_to?(:value) ? other.value : BigDecimal(other.to_s))
    rescue ArgumentError
      false
    end
  end
end

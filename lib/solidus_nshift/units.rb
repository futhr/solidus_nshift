# frozen_string_literal: true

require "bigdecimal"

module SolidusNshift
  module Units
    WEIGHT_TO_KG = {
      "kg" => BigDecimal("1"),
      "g" => BigDecimal("0.001"),
      "lb" => BigDecimal("0.45359237"),
      "oz" => BigDecimal("0.028349523125")
    }.freeze
    LENGTH_TO_CM = {
      "cm" => BigDecimal("1"),
      "mm" => BigDecimal("0.1"),
      "m" => BigDecimal("100"),
      "in" => BigDecimal("2.54")
    }.freeze

    module_function

    def weight_to_kg(value, unit)
      convert(value, WEIGHT_TO_KG, unit, "weight")
    end

    def length_to_cm(value, unit)
      convert(value, LENGTH_TO_CM, unit, "dimension")
    end

    def convert(value, conversions, unit, name)
      decimal = BigDecimal(value.to_s)
      raise ValidationError, "#{name} must be non-negative" unless decimal.finite? && !decimal.negative?

      decimal * conversions.fetch(unit.to_s) { raise ConfigurationError, "unsupported #{name} unit: #{unit}" }
    rescue ArgumentError, TypeError
      raise ValidationError, "#{name} is not a decimal value"
    end
    private_class_method :convert
  end
end

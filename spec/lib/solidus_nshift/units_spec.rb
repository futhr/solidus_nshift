# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::Units do
  describe ".weight_to_kg" do
    it "converts all supported units without floating-point drift" do
      expect(described_class.weight_to_kg("2", "kg")).to eq(BigDecimal("2"))
      expect(described_class.weight_to_kg("250", "g")).to eq(BigDecimal("0.25"))
      expect(described_class.weight_to_kg("2", "lb")).to eq(BigDecimal("0.90718474"))
      expect(described_class.weight_to_kg("4", "oz")).to eq(BigDecimal("0.1133980925"))
    end

    it "rejects invalid and negative values" do
      expect { described_class.weight_to_kg("nope", "kg") }.to raise_error(SolidusNshift::ValidationError)
      expect { described_class.weight_to_kg("-1", "kg") }.to raise_error(SolidusNshift::ValidationError)
    end

    it "rejects unknown units" do
      expect { described_class.weight_to_kg("1", "stone") }.to raise_error(SolidusNshift::ConfigurationError)
    end
  end

  describe ".length_to_cm" do
    it "converts all supported units" do
      expect(described_class.length_to_cm("2", "cm")).to eq(BigDecimal("2"))
      expect(described_class.length_to_cm("2", "mm")).to eq(BigDecimal("0.2"))
      expect(described_class.length_to_cm("2", "m")).to eq(BigDecimal("200"))
      expect(described_class.length_to_cm("2", "in")).to eq(BigDecimal("5.08"))
    end
  end
end

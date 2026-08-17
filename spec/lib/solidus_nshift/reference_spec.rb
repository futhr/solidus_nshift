# frozen_string_literal: true

require "unit_helper"

module ReferenceSpec
  FakeShipment = Struct.new(:order, :number, :id)
  FakeOrder = Struct.new(:store)
  FakeStore = Struct.new(:code)
end

RSpec.describe SolidusNshift::Reference do
  subject(:shipment) do
    ReferenceSpec::FakeShipment.new(
      ReferenceSpec::FakeOrder.new(ReferenceSpec::FakeStore.new("store/SE")), "H 123", 7
    )
  end

  it "builds a bounded provider-safe reference" do
    expect(described_class.for(shipment)).to eq("solidus:store-SE:H-123:1")
  end

  it "requires a positive integer revision" do
    expect { described_class.for(shipment, revision: 0) }
      .to raise_error(SolidusNshift::ValidationError, /positive/)
    expect { described_class.for(shipment, revision: "next") }
      .to raise_error(SolidusNshift::ValidationError, /integer/)
  end
end

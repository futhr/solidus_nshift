# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::PayloadFingerprint do
  it "is independent of hash insertion order and symbol versus string keys" do
    first = {shipment: {reference: "order-1", parcels: [{weight: 1, copies: 1}]}, test: true}
    second = {"test" => true, "shipment" => {"parcels" => [{"copies" => 1, "weight" => 1}], "reference" => "order-1"}}

    expect(described_class.call(first)).to eq(described_class.call(second))
  end

  it "retains array ordering because provider payload order can be significant" do
    expect(described_class.call(items: [1, 2])).not_to eq(described_class.call(items: [2, 1]))
  end
end

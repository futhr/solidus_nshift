# frozen_string_literal: true

require "unit_helper"

RSpec.describe SolidusNshift::ShipmentData::ShipmentLocator do
  it "finds the UUID only for the exact stable order reference" do
    response = fixture_json("tracking/search_result.json")

    expect(described_class.new.call(response, reference: "solidus:store:H123:1"))
      .to eq("shipment-uuid-2026-0001")
    expect(described_class.new.call(response, reference: "solidus:store:H124:1")).to be_nil
  end

  it "rejects a matched result without a UUID" do
    response = [{"orderNumber" => "solidus:store:H123:1"}]

    expect { described_class.new.call(response, reference: "solidus:store:H123:1") }
      .to raise_error(SolidusNshift::MalformedResponseError, /UUID/)
  end

  it "rejects undocumented wrapper shapes" do
    expect { described_class.new.call({"shipments" => []}, reference: "order-1") }
      .to raise_error(SolidusNshift::MalformedResponseError, /array/)
  end

  it "rejects malformed and ambiguous exact matches" do
    expect { described_class.new.call([nil], reference: "order-1") }
      .to raise_error(SolidusNshift::MalformedResponseError, /object/)

    duplicates = [
      {"orderNumber" => "order-1", "uuid" => "uuid-1"},
      {"additionalReference" => "order-1", "uuid" => "uuid-2"}
    ]
    expect { described_class.new.call(duplicates, reference: "order-1") }
      .to raise_error(SolidusNshift::ShipmentConflictError, /multiple shipments/)
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe SolidusNshift::SyncTracking do
  let(:data) { create_nshift_shipment(tracking_enabled: true) }
  let(:reference) { SolidusNshift::Reference.for(data[:shipment]) }
  let(:fulfillment) do
    SolidusNshift::Fulfillment.create!(
      shipment: data[:shipment],
      connection: data[:connection],
      rate_selection: data[:selection],
      merchant_reference: reference,
      state: "booked",
      provider_shipment_id: "10252317"
    )
  end
  let(:client) { instance_double(SolidusNshift::ShipmentData::Client) }
  let(:in_transit) do
    SolidusNshift::ShipmentData::EventNormalizer.new.call(
      nshift_fixture_json("tracking/in_transit.json").fetch("events").first
    )
  end
  let(:delivered) do
    SolidusNshift::ShipmentData::EventNormalizer.new.call(
      nshift_fixture_json("tracking/delivered.json").fetch("events").first
    )
  end

  before do
    allow(data[:connection]).to receive(:shipment_data_client).and_return(client)
    allow(client).to receive(:find_by_order_number).and_return(
      [{"orderNumber" => reference, "uuid" => "shipment-uuid-1"}]
    )
    allow(client).to receive(:events).and_return([in_transit])
  end

  it "locates the Shipment Data UUID and imports repeated events idempotently" do
    2.times { described_class.new(fulfillment:).call }

    expect(fulfillment.reload).to have_attributes(
      shipment_data_uuid: "shipment-uuid-1",
      tracking_status: "in_transit"
    )
    expect(fulfillment.tracking_events.count).to eq(1)
    expect(client).to have_received(:find_by_order_number).once
    expect(client).to have_received(:events).twice
  end

  it "does not regress a terminal status when older or unknown events arrive" do
    allow(client).to receive(:events).and_return([delivered])
    described_class.new(fulfillment:).call
    allow(client).to receive(:events).and_return([in_transit])

    described_class.new(fulfillment:).call

    expect(fulfillment.reload.tracking_status).to eq("delivered")
    expect(fulfillment.tracking_events.count).to eq(2)
  end

  it "uses a bounded historical search window for a late first sync" do
    fulfillment.update_columns(created_at: 2.months.ago, shipment_data_uuid: nil)
    allow(client).to receive(:find_by_order_number).and_return(
      [{"orderNumber" => reference, "uuid" => "shipment-uuid-1"}]
    )

    described_class.new(fulfillment:).call

    expect(client).to have_received(:find_by_order_number) do |start_time:, end_time:, **|
      expect(end_time - start_time).to be <= 31.days
    end
  end
end
